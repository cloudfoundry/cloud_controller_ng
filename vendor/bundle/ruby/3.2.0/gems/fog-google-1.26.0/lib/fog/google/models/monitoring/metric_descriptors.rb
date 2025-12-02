require "fog/core/collection"
require "fog/google/models/monitoring/metric_descriptor"

module Fog
  module Google
    class Monitoring
      class MetricDescriptors < Fog::Collection
        model Fog::Google::Monitoring::MetricDescriptor

        ##
        # Lists all Metric Descriptors.
        #
        # @param filter [String] Monitoring filter specifying which metric descriptors are to be returned.
        #   @see https://cloud.google.com/monitoring/api/v3/filters filter documentation
        # @param page_size [String] Maximum number of metric descriptors per page. Used for pagination.
        # @param page_token [String] The pagination token, which is used to page through large result sets.
        # @return [Array<Fog::Google::Monitoring::MetricDescriptor>] List of Metric Descriptors.
        def all(filter: nil, page_size: nil, page_token: nil)
          data = service.list_metric_descriptors(
            :filter => filter,
            :page_size => page_size,
            :page_token => page_token
          ).to_h[:metric_descriptors] || []

          load(data)
        end

        ##
        # Get a Metric Descriptors.
        #
        # @param metric_type [String] Metric type. For example, "custom.googleapis.com/test-metric"
        # @return [Fog::Google::Monitoring::MetricDescriptor] A Metric Descriptor.
        def get(metric_type)
          data = service.get_metric_descriptor(metric_type).to_h
          new(data)
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          nil
        end
      end
    end
  end
end
