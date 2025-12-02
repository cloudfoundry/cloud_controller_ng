module Fog
  module Google
    class Compute
      class Mock
        def set_subnetwork_private_ip_google_access(_subnetwork_name,
                                                    _region_name,
                                                    _private_ip_google_access)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        ##
        # Set whether VMs in this subnet can access Google services without
        # assigning external IP addresses through Private Google Access.
        #
        # @param subnetwork_name [String] the name of the subnetwork
        # @param region_name [String] the name of the subnetwork's region
        # @param private_ip_google_access [Boolean] whether
        #   private ip google access should be enforced
        # @return [Google::Apis::ComputeV1::Operation] an operation response
        #
        # @see https://cloud.google.com/compute/docs/reference/latest/subnetworks/setPrivateIpGoogleAccess
        def set_subnetwork_private_ip_google_access(subnetwork_name,
                                                    region_name,
                                                    private_ip_google_access)
          if region_name.start_with? "http"
            region_name = region_name.split("/")[-1]
          end
          @compute.set_subnetwork_private_ip_google_access(
            @project, region_name, subnetwork_name,
            ::Google::Apis::ComputeV1::SubnetworksSetPrivateIpGoogleAccessRequest.new(
              private_ip_google_access: private_ip_google_access
            )
          )
        end
      end
    end
  end
end
