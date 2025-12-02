require 'fog/openstack/models/collection'
require 'fog/openstack/monitoring/models/dimension_value'

module Fog
  module OpenStack
    class Monitoring
      class DimensionValues < Fog::OpenStack::Collection
        model Fog::OpenStack::Monitoring::DimensionValue

        def all(dimension_name, options = {})
          load_response(service.list_dimension_values(dimension_name, options), 'elements')
        end
      end
    end
  end
end
