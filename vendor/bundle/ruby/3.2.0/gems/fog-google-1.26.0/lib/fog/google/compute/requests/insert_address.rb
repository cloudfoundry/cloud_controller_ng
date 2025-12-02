module Fog
  module Google
    class Compute
      class Mock
        def insert_address(_address_name, _region_name, _options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # Create an address resource in the specified project
        # https://cloud.google.com/compute/docs/reference/latest/addresses/insert
        #
        # @param address_name [String] Project ID for this address
        # @param region_name [String] Region for address
        # @param options [Hash] Optional hash of options
        # @option options [String] :description Description of resource
        def insert_address(address_name, region_name, options = {})
          address = ::Google::Apis::ComputeV1::Address.new(
            name: address_name,
            description: options[:description]
          )
          @compute.insert_address(@project, region_name, address)
        end
      end
    end
  end
end
