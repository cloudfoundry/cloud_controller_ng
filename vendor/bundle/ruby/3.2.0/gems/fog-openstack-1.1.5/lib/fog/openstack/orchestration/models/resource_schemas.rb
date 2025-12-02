require 'fog/openstack/models/collection'

module Fog
  module OpenStack
    class Orchestration
      class ResourceSchemas < Fog::OpenStack::Collection
        def get(resource_type)
          service.show_resource_schema(resource_type).body
        rescue Fog::OpenStack::Compute::NotFound
          nil
        end
      end
    end
  end
end
