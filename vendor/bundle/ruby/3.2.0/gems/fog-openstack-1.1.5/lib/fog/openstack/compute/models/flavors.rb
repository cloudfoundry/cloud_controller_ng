require 'fog/openstack/models/collection'
require 'fog/openstack/compute/models/flavor'

module Fog
  module OpenStack
    class Compute
      class Flavors < Fog::OpenStack::Collection
        model Fog::OpenStack::Compute::Flavor

        def all(options = {})
          data = service.list_flavors_detail(options)
          load_response(data, 'flavors')
        end

        def summary(options = {})
          data = service.list_flavors(options)
          load_response(data, 'flavors')
        end

        def get(flavor_id)
          data = service.get_flavor_details(flavor_id).body['flavor']
          new(data)
        rescue Fog::OpenStack::Compute::NotFound
          nil
        end
      end
    end
  end
end
