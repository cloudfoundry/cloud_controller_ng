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

          message.strategy ||= DeploymentModel::ROLLING_STRATEGY

          target_state = DeploymentTargetState.new(app, message)

          previous_droplet = app.droplet
          target_state.apply_to_app(app, user_audit_info)

          if target_state.rollback_target_revision
            revision = RevisionResolver.rollback_app_revision(app, target_state.rollback_target_revision, user_audit_info)
            log_rollback_event(app.guid, user_audit_info.user_guid, target_state.rollback_target_revision.guid, message.strategy)
          else
            revision = RevisionResolver.update_app_revision(app, user_audit_info)
          end

          previous_deployment = DeploymentModel.find(app: app, status_value: DeploymentModel::ACTIVE_STATUS_VALUE)

          if app.stopped?
            return deployment_for_stopped_app(
              app,
              message,
              previous_deployment,
              previous_droplet,
              revision,
              target_state,
              user_audit_info
            )
          end

          desired_instances = desired_instances(app.oldest_web_process, previous_deployment)

          deployment = DeploymentModel.create(
            app: app,
            state: starting_state(message),
            status_value: DeploymentModel::ACTIVE_STATUS_VALUE,
            status_reason: DeploymentModel::DEPLOYING_STATUS_REASON,
            droplet: target_state.droplet,
            previous_droplet: previous_droplet,
            original_web_process_instance_count: desired_instances,
            revision_guid: revision&.guid,
            revision_version: revision&.version,
            strategy: message.strategy,
            max_in_flight: message.max_in_flight
          )
          MetadataUpdate.update(deployment, message)

          supersede_deployment(previous_deployment)

          process_instances = starting_process_instances(message, desired_instances)

          process = create_deployment_process(app, deployment.guid, revision, process_instances)
          # Need to transition from STOPPED to STARTED to engage the ProcessObserver to desire the LRP.
          # It'd be better to do this via Diego::Runner.new(process, config).start,
          # but it is nontrivial to get that working in test.
          process.reload.update(state: ProcessModel::STARTED)

          deployment.update(deploying_web_process: process)

          record_audit_event(deployment, target_state.droplet, user_audit_info, message)
        end

        deployment
      rescue RevisionResolver::NoUpdateRollback, Sequel::ValidationFailed, AppStart::InvalidApp => e
        error = DeploymentCreate::Error.new(e.message)
        error.set_backtrace(e.backtrace)
        raise error
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

      def deployment_for_stopped_app(app, message, previous_deployment, previous_droplet, revision, target_state, user_audit_info)
        # Do not create a revision here because AppStart will not handle the rollback case
        AppStart.start(app: app, user_audit_info: user_audit_info, create_revision: false)

        deployment = DeploymentModel.create(
          app: app,
          state: DeploymentModel::DEPLOYED_STATE,
          status_value: DeploymentModel::FINALIZED_STATUS_VALUE,
          status_reason: DeploymentModel::DEPLOYED_STATUS_REASON,
          droplet: target_state.droplet,
          previous_droplet: previous_droplet,
          original_web_process_instance_count: desired_instances(app.oldest_web_process, previous_deployment),
          revision_guid: revision&.guid,
          revision_version: revision&.version,
          strategy: message.strategy,
          max_in_flight: message.max_in_flight
        )

        MetadataUpdate.update(deployment, message)

        record_audit_event(deployment, target_state.droplet, user_audit_info, message)

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

      def starting_process_instances(message, desired_instances)
        if message.strategy == DeploymentModel::CANARY_STRATEGY
          1
        else
          [message.max_in_flight, desired_instances].min
        end
      end

      def log_rollback_event(app_guid, user_id, revision_id, strategy)
        TelemetryLogger.v3_emit(
          'rolled-back-app',
          {
            'app-id' => app_guid,
            'user-id' => user_id,
            'revision-id' => revision_id
          },
          { 'strategy' => strategy }
        )
      end
    end
  end
end
