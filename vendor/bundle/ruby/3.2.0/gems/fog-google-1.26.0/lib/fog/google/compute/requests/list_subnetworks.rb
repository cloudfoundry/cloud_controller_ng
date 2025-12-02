module Fog
  module Google
    class Compute
      class Mock
        def list_subnetworks(_region_name, _filter: nil, _max_results: nil,
                             _order_by: nil, _page_token: nil)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        ##
        # Retrieves a list of subnetworks specific to a region and project.
        #
        # @param region_name [String] the name of the subnetwork's region
        # @param filter [String] A filter expression for filtering listed resources.
        # @param max_results [Fixnum] Max number of results to return
        # @param order_by [String] Sorts list results by a certain order
        # @param page_token [String] specifies a page token to use
        # @return [Google::Apis::ComputeV1::SubnetworkList] list result
        #
        # @see https://cloud.google.com/compute/docs/reference/latest/subnetworks/list
        def list_subnetworks(region_name, filter: nil, max_results: nil,
                             order_by: nil, page_token: nil)
          if region_name.start_with? "http"
            region_name = region_name.split("/")[-1]
          end
          @compute.list_subnetworks(@project, region_name,
                                    filter: filter,
                                    max_results: max_results,
                                    order_by: order_by,
                                    page_token: page_token)
        end
      end
    end
  end
end
