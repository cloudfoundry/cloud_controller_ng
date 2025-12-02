require 'fog/openstack/models/collection'
require 'fog/openstack/compute/models/aggregate'

module Fog
  module OpenStack
    class Compute
      class Aggregates < Fog::OpenStack::Collection
        model Fog::OpenStack::Compute::Aggregate

        def all(options = {})
          load_response(service.list_aggregates(options), 'aggregates')
        end

        def find_by_id(id)
          new(service.get_aggregate(id).body['aggregate'])
        end
        alias get find_by_id

        def destroy(id)
          aggregate = find_by_id(id)
          aggregate.destroy
        end
      end
    end
  end
end
