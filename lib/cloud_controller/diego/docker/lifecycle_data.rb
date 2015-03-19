module VCAP::CloudController
  module Diego
    module Docker
      class LifecycleData
        attr_accessor :docker_image

        def message
          message = { docker_image: docker_image }
          schema.validate(message)
          message
        end

        private

        def schema
          @schema ||= Membrane::SchemaParser.parse do
            { docker_image: String }
          end
        end
      end
    end
  end
end
