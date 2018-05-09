module VCAP::CloudController
  class DeploymentCreate
    class << self
      def create(app:, user_audit_info:)
        deployment = DeploymentModel.new(app: app, state: DeploymentModel::DEPLOYING_STATE, droplet: app.droplet)
        DeploymentModel.db.transaction do
          deployment.save

          web_process = app.web_process
          process_type = "web-deployment-#{deployment.guid}"
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
          )

          web_process.routes.each { |r| RouteMappingCreate.add(user_audit_info, r, process) }
        end

        deployment
      end
    end
  end
end
