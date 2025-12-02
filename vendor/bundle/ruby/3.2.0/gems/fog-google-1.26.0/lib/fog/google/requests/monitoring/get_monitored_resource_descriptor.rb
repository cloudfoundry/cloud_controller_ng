module Fog
  module Google
    class Monitoring
      class Real
        def get_monitored_resource_descriptor(resource_type)
          @monitoring.get_project_monitored_resource_descriptor(
            "projects/#{@project}/monitoredResourceDescriptors/#{resource_type}"
          )
        end
      end

      class Mock
        def get_monitored_resource_descriptor(_resource_type)
          raise Fog::Errors::MockNotImplemented
        end
      end
    end
  end
end
