module Fog
  module Google
    class Compute
      class Mock
        def list_aggregated_disks(_options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # Retrieves an aggregated list of disks
        # https://cloud.google.com/compute/docs/reference/latest/disks/aggregatedList
        #
        # @param options [Hash] Optional hash of options
        # @option options [String] :filter Filter expression for filtering listed resources
        # @option options [String] :max_results
        # @option options [String] :order_by
        # @option options [String] :page_token
        def list_aggregated_disks(filter: nil, max_results: nil,
                                  order_by: nil, page_token: nil)
          @compute.list_aggregated_disk(
            @project,
            filter: filter, max_results: max_results,
            order_by: order_by, page_token: page_token
          )
        end
      end
    end
  end
end
