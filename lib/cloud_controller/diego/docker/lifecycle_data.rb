module VCAP::CloudController
  module Diego
    module Docker
      class LifecycleData
        attr_accessor :docker_image
        attr_accessor :docker_login_server
        attr_accessor :docker_user
        attr_accessor :docker_password
        attr_accessor :docker_email

        def message
          message = {
            docker_image: docker_image,
            docker_login_server: docker_login_server,
            docker_user: docker_user,
            docker_password: docker_password,
            docker_email: docker_email
          }.delete_if { |k, v| v.blank? }

          schema.validate(message)
          message
        end

        private

        def schema
          @schema ||= Membrane::SchemaParser.parse do
            {
              docker_image: String,
              optional(:docker_login_server) => String,
              optional(:docker_user) => String,
              optional(:docker_password) => String,
              optional(:docker_email) => String,
            }
          end
        end
      end
    end
  end
end
