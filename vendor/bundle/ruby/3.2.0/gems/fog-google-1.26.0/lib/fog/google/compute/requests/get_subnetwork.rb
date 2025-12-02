module Fog
  module Google
    class Compute
      class Mock
        def get_subnetwork(_subnetwork_name, _region_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        ##
        # Returns the specified subnetwork.
        #
        # @param subnetwork_name [String] the name of the subnetwork
        # @param region_name [String] the name of the subnetwork's region
        # @return [Google::Apis::ComputeV1::Operation] an operation response
        #
        # @see https://cloud.google.com/compute/docs/reference/latest/subnetworks/get
        def get_subnetwork(subnetwork_name, region_name)
          subnetwork_name = subnetwork_name.split("/")[-1] if subnetwork_name.start_with? "http"
          region_name = region_name.split("/")[-1] if region_name.start_with? "http"
          @compute.get_subnetwork(@project, region_name, subnetwork_name)
        end
      end
    end
  end
end
