require 'repositories/deployment_event_repository'
require 'actions/revision_resolver'
require 'cloud_controller/deployments/deployment_target_state'

module VCAP::CloudController
  class DeploymentCreate
    class Error < StandardError; end

    class << self
      def create(app:, user_audit_info:, message:)
        target_state = DeploymentTargetState.new(app, message)

        previous_droplet = app.droplet
        target_state.apply_to_app(app, user_audit_info)

        revision = if target_state.rollback_target_revision
                     RevisionResolver.rollback_app_revision(app, target_state.rollback_target_revision, user_audit_info)
                   else
                     RevisionResolver.update_app_revision(app, user_audit_info)
                   end

        previous_deployment = DeploymentModel.find(app: app, state: [DeploymentModel::DEPLOYING_STATE, DeploymentModel::FAILING_STATE])
        deployment = DeploymentModel.create(
          app: app,
          state: DeploymentModel::DEPLOYING_STATE,
          droplet: target_state.droplet,
          previous_droplet: previous_droplet,
          original_web_process_instance_count: desired_instances(app.oldest_web_process, previous_deployment),
          revision_guid: revision&.guid,
          revision_version: revision&.version,
        )
        MetadataUpdate.update(deployment, message)

        DeploymentModel.db.transaction do
          if previous_deployment
            new_state = previous_deployment.deploying? ? DeploymentModel::DEPLOYED_STATE : DeploymentModel::FAILED_STATE
            previous_deployment.update(state: new_state)
          end

          process = create_deployment_process(app, deployment.guid, revision)
          # Need to transition from STOPPED to STARTED to engage the ProcessObserver to desire the LRP.
          # It'd be better to do this via Diego::Runner.new(process, config).start,
          # but it is nontrivial to get that working in test.
          process.reload.update(state: ProcessModel::STARTED)

          deployment.update(deploying_web_process: process)
        end
        record_audit_event(deployment, target_state.droplet, user_audit_info, message)

        deployment
      rescue RevisionResolver::NoUpdateRollback => e
        error = DeploymentCreate::Error.new(e.message)
        error.set_backtrace(e.backtrace)
        raise error
      end

      def create_deployment_process(app, deployment_guid, revision)
        process = clone_existing_web_process(app, revision)

        DeploymentProcessModel.create(
          deployment_guid: deployment_guid,
          process_guid: process.guid,
          process_type: process.type
        )

        process
      end

      def clone_existing_web_process(app, revision)
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
          instances: 1,
          command: command,
          memory: web_process.memory,
          file_descriptors: web_process.file_descriptors,
          disk_quota: web_process.disk_quota,
          metadata: web_process.metadata,
          detected_buildpack: web_process.detected_buildpack,
          health_check_timeout: web_process.health_check_timeout,
          health_check_type: web_process.health_check_type,
          health_check_http_endpoint: web_process.health_check_http_endpoint,
          health_check_invocation_timeout: web_process.health_check_invocation_timeout,
          enable_ssh: web_process.enable_ssh,
          ports: web_process.ports,
          revision: revision,
        )
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

      def desired_instances(original_web_process, previous_deployment)
        if previous_deployment
          previous_deployment.original_web_process_instance_count
        else
          original_web_process.instances
        end
      end
    end
  end
end
