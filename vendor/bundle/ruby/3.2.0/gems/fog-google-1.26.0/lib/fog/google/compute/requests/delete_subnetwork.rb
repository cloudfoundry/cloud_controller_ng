module Fog
  module Google
    class Compute
      class Mock
        def delete_subnetwork(_subnetwork_name, _region_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        ##
        # Delete a subnetwork.
        #
        # @param subnetwork_name [String] the name of the subnetwork to delete
        # @param region_name [String] the name of the subnetwork's region
        #
        # @return [Google::Apis::ComputeV1::Operation] delete operation
        #
        # @see https://cloud.google.com/compute/docs/reference/latest/subnetworks/delete
        def delete_subnetwork(subnetwork_name, region_name)
          if region_name.start_with? "http"
            region_name = region_name.split("/")[-1]
          end
          @compute.delete_subnetwork(@project, region_name, subnetwork_name)
        end
      end
    end
  end
end
