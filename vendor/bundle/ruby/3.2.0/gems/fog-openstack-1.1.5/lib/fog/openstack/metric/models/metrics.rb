require 'fog/openstack/models/collection'
require 'fog/openstack/metric/models/metric'

module Fog
  module OpenStack
    class Metric
      class Metrics < Fog::OpenStack::Collection

        model Fog::OpenStack::Metric::Metric

        def all(options = {})
          load_response(service.list_metrics(options))
        end

        def find_by_id(metric_id)
          resource = service.get_metric(metric_id).body
          new(resource)
        rescue Fog::OpenStack::Metric::NotFound
          nil
        end

        def find_measures_by_id(metric_id, options = {})
          resource = service.get_metric_measures(metric_id, options).body
          new(resource)
        rescue Fog::OpenStack::Metric::NotFound
          nil
        end
      end
    end
  end
end
