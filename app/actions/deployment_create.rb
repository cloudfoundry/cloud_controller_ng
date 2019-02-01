require 'repositories/deployment_event_repository'

module VCAP::CloudController
  class DeploymentCreate
    class Error < StandardError; end

    class << self
      def create(app:, user_audit_info:, message:)
        droplet = choose_desired_droplet(app, message.droplet_guid, message.revision_guid)

        previous_droplet = app.droplet
        begin
          AppAssignDroplet.new(user_audit_info).assign(app, droplet)
        rescue AppAssignDroplet::Error => e
          raise Error.new(e.message)
        end

        given_revision = RevisionModel.find(guid: message.revision_guid)
        if given_revision
          app.db.transaction do
            app.lock!
            app.update(environment_variables: given_revision.environment_variables)
            app.save
          end
        end

        web_process = app.oldest_web_process
        previous_deployment = DeploymentModel.find(app: app, state: DeploymentModel::DEPLOYING_STATE)

        desired_instances = web_process.instances
        if previous_deployment
          desired_instances = previous_deployment.original_web_process_instance_count
        end

        new_revision = app.can_create_revision? ? RevisionCreate.create(app) : web_process.revision

        deployment = DeploymentModel.new(
          app: app,
          state: DeploymentModel::DEPLOYING_STATE,
          droplet: droplet,
          previous_droplet: previous_droplet,
          original_web_process_instance_count: desired_instances,
          revision_guid: new_revision&.guid,
          revision_version: new_revision&.version,
        )

        DeploymentModel.db.transaction do
          if previous_deployment
            previous_deployment.update(state: DeploymentModel::DEPLOYED_STATE)
            previous_deployment.save
          end

          deployment.save

          MetadataUpdate.update(deployment, message)

          process = create_deployment_process(app, deployment.guid, web_process, new_revision)
          deployment.update(deploying_web_process: process)
        end
        record_audit_event(deployment, droplet, user_audit_info)

        deployment
      end

      private

      def choose_desired_droplet(app, droplet_guid, revision_guid)
        if droplet_guid
          droplet = DropletModel.find(guid: droplet_guid)
        elsif revision_guid
          revision = RevisionModel.find(guid: revision_guid)
          raise Error.new('The revision does not exist') unless revision

          droplet = DropletModel.find(guid: revision.droplet_guid)
          raise Error.new('Invalid revision. Please specify a revision with a valid droplet in the request.') unless droplet

        else
          droplet = app.droplet
          raise Error.new('Invalid droplet. Please specify a droplet in the request or set a current droplet for the app.') unless droplet
        end
        droplet
      end

      def create_deployment_process(app, deployment_guid, web_process, revision)
        process = clone_existing_web_process(app, web_process, revision)

        DeploymentProcessModel.create(
          deployment_guid: deployment_guid,
          process_guid: process.guid,
          process_type: process.type
        )

        # Need to transition from STOPPED to STARTED to engage the ProcessObserver to desire the LRP
        process.reload.update(state: ProcessModel::STARTED)

        process
      end

      def clone_existing_web_process(app, web_process, revision)
        ProcessModel.create(
          app: app,
          type: ProcessTypes::WEB,
          state: ProcessModel::STOPPED,
          instances: 1,
          command: web_process.command,
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
          revision: revision
        )
      end

      def record_audit_event(deployment, droplet, user_audit_info)
        app = deployment.app
        Repositories::DeploymentEventRepository.record_create(
          deployment,
            droplet,
            user_audit_info,
            app.name,
            app.space_guid,
            app.space.organization_guid
        )
      end
    end
  end
end
