module Fog
  module Google
    class Compute
      class Mock
        def insert_global_address(_address_name, _options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        INSERTABLE_ADDRESS_FIELDS = %i{description ip_version}.freeze

        def insert_global_address(address_name, options = {})
          opts = options.select { |k, _| INSERTABLE_ADDRESS_FIELDS.include? k }
                        .merge(:name => address_name)
          @compute.insert_global_address(
            @project, ::Google::Apis::ComputeV1::Address.new(**opts)
          )
        end
      end
    end
  end
end
