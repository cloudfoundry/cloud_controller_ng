require 'fog/openstack/models/collection'
require 'fog/openstack/metric/models/resource'

module Fog
  module OpenStack
    class Metric
      class Resources < Fog::OpenStack::Collection

        model Fog::OpenStack::Metric::Resource

        def all(options = {})
          load_response(service.list_resources(options))
        end

        def find_by_id(resource_id)
          resource = service.get_resource(resource_id).body
          new(resource)
        rescue Fog::OpenStack::Metric::NotFound
          nil
        end
      end
    end
  end
end
