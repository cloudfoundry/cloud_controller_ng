module Fog
  module Google
    class Compute
      class Mock
        def expand_subnetwork_ip_cidr_range(_subnetwork, _region, _ip_cidr_range)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        ##
        # Expands the IP CIDR range of the subnetwork to a specified value.
        #
        # @param subnetwork [String] the name of the subnetwork
        # @param region [String] the name of the subnetwork's region
        # @param ip_cidr_range [String] The IP of internal addresses that are legal on
        #   this subnetwork
        #
        # @return [Google::Apis::ComputeV1::SubnetworkList] list result
        #
        # @see https://cloud.google.com/compute/docs/reference/latest/subnetworks/expandIpCidrRange
        def expand_subnetwork_ip_cidr_range(subnetwork, region, ip_cidr_range)
          if region.start_with? "http"
            region = region.split("/")[-1]
          end
          @compute.expand_subnetwork_ip_cidr_range(
            @project, region, subnetwork,
            ::Google::Apis::ComputeV1::SubnetworksExpandIpCidrRangeRequest.new(
              ip_cidr_range: ip_cidr_range
            )
          )
        end
      end
    end
  end
end
