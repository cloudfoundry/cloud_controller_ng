require "fog/core/collection"
require "fog/google/models/monitoring/monitored_resource_descriptor"

module Fog
  module Google
    class Monitoring
      class MonitoredResourceDescriptors < Fog::Collection
        model Fog::Google::Monitoring::MonitoredResourceDescriptor

        ##
        # Lists all Monitored Resource Descriptors.
        #
        # @param filter [String] The monitoring filter used to search against existing descriptors.
        #   @see https://cloud.google.com/monitoring/api/v3/filters filter documentation
        # @param page_size [String]  Maximum number of metric descriptors per page. Used for pagination.
        # @param page_token [String]  The pagination token, which is used to page through large result sets.
        # @return [Array<Fog::Google::Monitoring::MetricDescriptor>] List of Monitored Resource Descriptors.
        def all(filter: nil, page_size: nil, page_token: nil)
          data = service.list_monitored_resource_descriptors(
            :filter => filter,
            :page_size => page_size,
            :page_token => page_token
          ).to_h[:resource_descriptors] || []
          load(data)
        end

        def get(resource_type)
          data = service.get_monitored_resource_descriptor(resource_type).to_h
          new(data)
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          nil
        end
      end
    end
  end
end
