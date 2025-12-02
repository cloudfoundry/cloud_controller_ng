module Fog
  module Google
    class Compute
      class Mock
        def delete_address(_address_name, _region_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # Delete an address resource in the specified project
        # https://cloud.google.com/compute/docs/reference/latest/addresses/delete
        #
        # @param address_name [String] Project ID for this address
        # @param region_name [String] Region for address
        def delete_address(address_name, region_name)
          @compute.delete_address(@project, region_name, address_name)
        end
      end
    end
  end
end
