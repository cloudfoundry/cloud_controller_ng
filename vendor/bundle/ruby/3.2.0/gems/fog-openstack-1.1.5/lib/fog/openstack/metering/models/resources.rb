require 'fog/openstack/models/collection'
require 'fog/openstack/metering/models/resource'

module Fog
  module OpenStack
    class Metering
      class Resources < Fog::OpenStack::Collection
        model Fog::OpenStack::Metering::Resource

        def all(_detailed = true)
          load_response(service.list_resources)
        end

        def find_by_id(resource_id)
          resource = service.get_resource(resource_id).body
          new(resource)
        rescue Fog::OpenStack::Metering::NotFound
          nil
        end
      end
    end
  end
end
