require 'fog/openstack/models/collection'
require 'fog/openstack/monitoring/models/metric'
require 'fog/openstack/monitoring/models/dimension_values'

module Fog
  module OpenStack
    class Monitoring
      class Metrics < Fog::OpenStack::Collection
        model Fog::OpenStack::Monitoring::Metric

        def all(options = {})
          load_response(service.list_metrics(options), 'elements')
        end

        def list_metric_names(options = {})
          load_response(service.list_metric_names(options), 'elements')
        end

        def create(attributes)
          super(attributes)
        end

        def create_metric_array(metrics_list = [])
          service.create_metric_array(metrics_list)
        end

        def list_dimension_values(dimension_name, options = {})
          dimension_value = Fog::OpenStack::Monitoring::DimensionValues.new
          dimension_value.load_response(
            service.list_dimension_values(dimension_name, options), 'elements'
          )
        end
      end
    end
  end
end
