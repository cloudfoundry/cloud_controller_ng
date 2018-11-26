require 'repositories/deployment_event_repository'
require 'actions/revision_create'

module VCAP::CloudController
  class DeploymentCreate
    class SetCurrentDropletError < StandardError; end

    class << self
      def create(app:, user_audit_info:, droplet:)
        previous_droplet = app.droplet
        begin
          AppAssignDroplet.new(user_audit_info).assign(app, droplet)
        rescue AppAssignDroplet::Error => e
          raise SetCurrentDropletError.new(e.message)
        end

        web_process = app.oldest_web_process
        previous_deployment = DeploymentModel.find(app: app, state: DeploymentModel::DEPLOYING_STATE)

        desired_instances = web_process.instances
        if previous_deployment
          desired_instances = previous_deployment.original_web_process_instance_count
        end

        deployment = DeploymentModel.new(
          app: app,
          state: DeploymentModel::DEPLOYING_STATE,
          droplet: droplet,
          previous_droplet: previous_droplet,
          original_web_process_instance_count: desired_instances,
        )

        DeploymentModel.db.transaction do
          if previous_deployment
            previous_deployment.update(state: DeploymentModel::DEPLOYED_STATE)
            previous_deployment.save
          end
          deployment.save

          # This revision should be assigned to the app's non-web processes when restarted in the deployment updater
          revision = RevisionCreate.create(app)
          process = create_deployment_process(app, deployment.guid, web_process, revision)
          deployment.update(deploying_web_process: process, revision_guid: revision.guid, revision_version: revision.version)
          web_process.routes.each { |r| RouteMappingCreate.add(user_audit_info: user_audit_info, route: r, process_type: process.type, app: app) }
        end
        record_audit_event(deployment, droplet, user_audit_info)
        deployment
      end

      private

      def create_deployment_process(app, deployment_guid, web_process, revision)
        process_type = "web-deployment-#{deployment_guid}"

        process = ProcessModel.create(
          app: app,
          type: process_type,
          state: ProcessModel::STARTED,
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
          revision: revision,
        )

        DeploymentProcessModel.create(
          deployment_guid: deployment_guid,
          process_guid: process.guid,
          process_type: process.type
        )

        process
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
