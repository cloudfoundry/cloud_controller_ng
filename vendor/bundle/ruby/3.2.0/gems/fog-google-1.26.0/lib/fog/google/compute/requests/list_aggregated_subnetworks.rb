module Fog
  module Google
    class Compute
      class Mock
        def list_aggregated_subnetworks(_options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        ##
        # Retrieves an aggregated list of subnetworks across a project.
        #
        # @param filter [String] A filter expression for filtering listed resources.
        # @param max_results [Fixnum] Max number of results to return
        # @param order_by [String] Sorts list results by a certain order
        # @param page_token [String] specifies a page token to use
        # @return [Google::Apis::ComputeV1::SubnetworkAggregatedList] list result
        #
        # @see https://cloud.google.com/compute/docs/reference/latest/subnetworks/aggregatedList
        def list_aggregated_subnetworks(filter: nil, max_results: nil,
                                        page_token: nil, order_by: nil)
          @compute.aggregated_subnetwork_list(
            @project,
            filter: filter,
            max_results: max_results,
            page_token: page_token,
            order_by: order_by
          )
        end
      end
    end
  end
end
