require 'repositories/deployment_event_repository'
require 'actions/revision_resolver'
require 'cloud_controller/deployments/deployment_target_state'

module VCAP::CloudController
  class DeploymentCreate
    class Error < StandardError; end

    class << self
      def create(app:, user_audit_info:, message:)
        deployment = nil

        DeploymentModel.db.transaction do
          app.lock!

          # Stopped apps will have quota validated since we scale their process up immediately later
          validate_quota!(message, app) unless app.stopped?

          message.strategy ||= DeploymentModel::ROLLING_STRATEGY

          target_state = DeploymentTargetState.new(app, message)

          previous_droplet = app.droplet
          target_state.apply_to_app(app, user_audit_info)

          if target_state.rollback_target_revision
            revision = RevisionResolver.rollback_app_revision(app, target_state.rollback_target_revision, user_audit_info)
            log_rollback_event(app.guid, user_audit_info.user_guid, target_state.rollback_target_revision.guid, message.strategy, message.max_in_flight, message.canary_steps)
          else
            revision = RevisionResolver.update_app_revision(app, user_audit_info)
          end

          previous_deployment = DeploymentModel.find(app: app, status_value: DeploymentModel::ACTIVE_STATUS_VALUE)

          deployment = create_deployment(
            app,
            message,
            previous_deployment,
            previous_droplet,
            revision,
            target_state,
            user_audit_info
          )

          if app.stopped?
            process = app.newest_web_process
          else
            process_instances = starting_process_instances(deployment, desired_instances(app.oldest_web_process, previous_deployment))
            process = create_deployment_process(app, deployment.guid, revision, process_instances)
          end

          process.memory = message.memory_in_mb if message.memory_in_mb
          process.disk_quota = message.disk_in_mb if message.disk_in_mb
          process.log_rate_limit = message.log_rate_limit_in_bytes_per_second if message.log_rate_limit_in_bytes_per_second

          if app.stopped?
            process.instances = message.web_instances if message.web_instances

            process.save_changes

            # Do not create a revision here because AppStart will not handle the rollback case
            AppStart.start(app: app, user_audit_info: user_audit_info, create_revision: false)
            deployment.update(state: DeploymentModel::DEPLOYED_STATE,
                              status_value: DeploymentModel::FINALIZED_STATUS_VALUE,
                              status_reason: DeploymentModel::DEPLOYED_STATUS_REASON)
            record_audit_event(deployment, target_state.droplet, user_audit_info, message)
            return deployment
          end

          process.save

          supersede_deployment(previous_deployment)

          # Need to transition from STOPPED to STARTED to engage the ProcessObserver to desire the LRP.
          # It'd be better to do this via Diego::Runner.new(process, config).start,
          # but it is nontrivial to get that working in test.
          process.reload.update(state: ProcessModel::STARTED)

          deployment.update(deploying_web_process: process)

          record_audit_event(deployment, target_state.droplet, user_audit_info, message)
        end

        deployment
      rescue RevisionResolver::NoUpdateRollback, Sequel::ValidationFailed, AppStart::InvalidApp => e
        raise handle_deployment_create_error(e, app)
      end

      def handle_deployment_create_error(e, app)
        space_quota_errors = [:space_quota_exceeded.to_s, :space_app_instance_limit_exceeded.to_s]
        org_quota_errors = [:quota_exceeded.to_s, :app_instance_limit_exceeded.to_s]
        if space_quota_errors.any? { |substring| e.message.include?(substring) }
          space_error_msg = " for space #{app.space.name}. This space's quota may not be large enough to support rolling deployments or your configured max-in-flight."
          error = DeploymentCreate::Error.new(e.message + space_error_msg)
        elsif org_quota_errors.any? { |substring| e.message.include?(substring) }
          org_error_msg_1 = " for organization #{app.organization.name}. "
          org_error_msg_2 = "This organization's quota may not be large enough to support rolling deployments or your configured max-in-flight."
          error = DeploymentCreate::Error.new(e.message + org_error_msg_1 + org_error_msg_2)
        else
          error = DeploymentCreate::Error.new(e.message)
        end
        error.set_backtrace(e.backtrace)
        error
      end

      def create_deployment_process(app, deployment_guid, revision, process_instances)
        process = clone_existing_web_process(app, revision, process_instances)

        DeploymentProcessModel.create(
          deployment_guid: deployment_guid,
          process_guid: process.guid,
          process_type: process.type
        )

        process
      end

      def clone_existing_web_process(app, revision, process_instances)
        web_process = app.newest_web_process
        command = if revision
                    revision.commands_by_process_type[ProcessTypes::WEB]
                  else
                    web_process.command
                  end
        ProcessModel.create(
          app: app,
          type: ProcessTypes::WEB,
          state: ProcessModel::STOPPED,
          instances: process_instances,
          command: command,
          user: web_process.user,
          memory: web_process.memory,
          file_descriptors: web_process.file_descriptors,
          disk_quota: web_process.disk_quota,
          log_rate_limit: web_process.log_rate_limit,
          metadata: web_process.metadata, # execution_metadata, not labels & annotations metadata!
          detected_buildpack: web_process.detected_buildpack,
          health_check_timeout: web_process.health_check_timeout,
          health_check_type: web_process.health_check_type,
          health_check_http_endpoint: web_process.health_check_http_endpoint,
          health_check_invocation_timeout: web_process.health_check_invocation_timeout,
          health_check_interval: web_process.health_check_interval,
          readiness_health_check_type: web_process.readiness_health_check_type,
          readiness_health_check_http_endpoint: web_process.readiness_health_check_http_endpoint,
          readiness_health_check_invocation_timeout: web_process.readiness_health_check_invocation_timeout,
          readiness_health_check_interval: web_process.readiness_health_check_interval,
          enable_ssh: web_process.enable_ssh,
          ports: web_process.ports,
          revision: revision
        ).tap do |p|
          web_process.labels.each do |label|
            ProcessLabelModel.create(
              key_prefix: label.key_prefix,
              key_name: label.key_name,
              value: label.value,
              resource_guid: p.guid
            )
          end
          web_process.annotations.each do |annotation|
            ProcessAnnotationModel.create(
              key_prefix: annotation.key_prefix,
              key_name: annotation.key_name,
              value: annotation.value,
              resource_guid: p.guid
            )
          end
        end
      end

      def record_audit_event(deployment, droplet, user_audit_info, message)
        app = deployment.app
        type = message.revision_guid ? 'rollback' : nil
        Repositories::DeploymentEventRepository.record_create(
          deployment,
          droplet,
          user_audit_info,
          app.name,
          app.space_guid,
          app.space.organization_guid,
          message.audit_hash,
          type
        )
      end

      private

      def validate_quota!(message, app)
        return if message.web_instances.blank? && message.memory_in_mb.blank? && message.log_rate_limit_in_bytes_per_second.blank?

        current_web_process = app.newest_web_process
        current_web_process.instances = message.web_instances if message.web_instances
        current_web_process.memory = message.memory_in_mb if message.memory_in_mb
        current_web_process.disk_quota = message.disk_in_mb if message.disk_in_mb
        current_web_process.log_rate_limit = message.log_rate_limit_in_bytes_per_second if message.log_rate_limit_in_bytes_per_second
        # Quotas wont get checked unless the process is started
        current_web_process.state = ProcessModel::STARTED
        current_web_process.validate

        raise Sequel::ValidationFailed.new(current_web_process) unless current_web_process.valid?

        current_web_process.reload
      end

      def create_deployment(app, message, previous_deployment, previous_droplet, revision, target_state, _user_audit_info)
        deployment = DeploymentModel.create(
          app: app,
          state: starting_state(message),
          status_value: DeploymentModel::ACTIVE_STATUS_VALUE,
          status_reason: DeploymentModel::DEPLOYING_STATUS_REASON,
          droplet: target_state.droplet,
          previous_droplet: previous_droplet,
          original_web_process_instance_count: desired_instances(app.oldest_web_process, previous_deployment),
          revision_guid: revision&.guid,
          revision_version: revision&.version,
          strategy: message.strategy,
          max_in_flight: message.max_in_flight,
          memory_in_mb: message.memory_in_mb,
          disk_in_mb: message.disk_in_mb,
          log_rate_limit_in_bytes_per_second: message.log_rate_limit_in_bytes_per_second,
          canary_steps: message.canary_steps,
          web_instances: message.web_instances
        )
        MetadataUpdate.update(deployment, message)
        deployment
      end

      def desired_instances(original_web_process, previous_deployment)
        if previous_deployment
          previous_deployment.original_web_process_instance_count
        else
          original_web_process.instances
        end
      end

      def supersede_deployment(previous_deployment)
        return unless previous_deployment

        new_state = if previous_deployment.state == DeploymentModel::DEPLOYING_STATE
                      DeploymentModel::DEPLOYED_STATE
                    else
                      DeploymentModel::CANCELED_STATE
                    end
        previous_deployment.update(
          state: new_state,
          status_value: DeploymentModel::FINALIZED_STATUS_VALUE,
          status_reason: DeploymentModel::SUPERSEDED_STATUS_REASON
        )
      end

      def starting_state(message)
        if message.strategy == DeploymentModel::CANARY_STRATEGY
          DeploymentModel::PREPAUSED_STATE
        else
          DeploymentModel::DEPLOYING_STATE
        end
      end

      def starting_process_instances(deployment, desired_instances)
        starting_process_count = if deployment.strategy == DeploymentModel::CANARY_STRATEGY
                                   deployment.canary_step[:canary]
                                 elsif deployment.web_instances
                                   deployment.web_instances
                                 else
                                   desired_instances
                                 end

        [deployment.max_in_flight, starting_process_count].min
      end

      def log_rollback_event(app_guid, user_id, revision_id, strategy, max_in_flight, canary_steps)
        TelemetryLogger.v3_emit(
          'rolled-back-app',
          {
            'app-id' => app_guid,
            'user-id' => user_id,
            'revision-id' => revision_id
          },
          {
            'strategy' => strategy,
            'max-in-flight' => max_in_flight,
            'canary-steps' => canary_steps
          }
        )
      end
    end
  end
end
