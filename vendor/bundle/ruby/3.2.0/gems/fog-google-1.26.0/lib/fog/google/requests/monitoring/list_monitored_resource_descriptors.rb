module Fog
  module Google
    class Monitoring
      ##
      # Describes the schema of a MonitoredResource (a resource object that can be used for monitoring, logging,
      # billing, or other purposes) using a type name and a set of labels.
      #
      # @see https://cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.monitoredResourceDescriptors/list
      class Real
        def list_monitored_resource_descriptors(filter: nil, page_size: nil, page_token: nil)
          @monitoring.list_project_monitored_resource_descriptors(
            "projects/#{@project}",
            :filter => filter,
            :page_size => page_size,
            :page_token => page_token
          )
        end
      end

      class Mock
        def list_monitored_resource_descriptors(_filter, _page_size, _page_token)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
