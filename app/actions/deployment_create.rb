module VCAP::CloudController
  class DeploymentCreate
    class SetCurrentDropletError < StandardError; end

    class << self
      def create(app:, user_audit_info:, droplet:)
        previous_droplet = app.droplet
        begin
          SetCurrentDroplet.new(user_audit_info).update_to(app, droplet)
        rescue SetCurrentDroplet::Error => e
          raise SetCurrentDropletError.new(e.message)
        end

        deployment = DeploymentModel.new(
          app: app,
          state: DeploymentModel::DEPLOYING_STATE,
          droplet: droplet,
          previous_droplet: previous_droplet
        )

        DeploymentModel.db.transaction do
          deployment.save

          web_process = app.web_process
          process = create_deployment_process(app, deployment.guid, web_process)

          deployment.update(deploying_web_process: process)
          web_process.routes.each { |r| RouteMappingCreate.add(user_audit_info, r, process) }
        end

        deployment
      end

      private

      def create_deployment_process(app, deployment_guid, web_process)
        process_type = "web-deployment-#{deployment_guid}"

        ProcessModel.create(
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
        )
      end
    end
  end
end
