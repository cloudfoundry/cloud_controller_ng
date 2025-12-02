module Fog
  module Google
    class Monitoring
      ##
      # Lists metric descriptors that match a filter.
      #
      # @see https://cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.metricDescriptors/list
      class Real
        def list_metric_descriptors(filter: nil, page_size: nil, page_token: nil)
          @monitoring.list_project_metric_descriptors(
            "projects/#{@project}",
            :filter => filter,
            :page_size => page_size,
            :page_token => page_token
          )
        end
      end

      class Mock
        def list_metric_descriptors(_options = {})
          raise Fog::Errors::MockNotImplemented
        end
      end
    end
  end
end
