module Fog
  module Google
    class Compute
      class Mock
        def list_aggregated_addresses(_options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        # Retrieves an aggregated list of addresses
        # https://cloud.google.com/compute/docs/reference/latest/addresses/aggregatedList
        # @param options [Hash] Optional hash of options
        # @option options [String] :filter Filter expression for filtering listed resources
        def list_aggregated_addresses(options = {})
          @compute.list_aggregated_addresses(@project, **options)
        end
      end
    end
  end
end
