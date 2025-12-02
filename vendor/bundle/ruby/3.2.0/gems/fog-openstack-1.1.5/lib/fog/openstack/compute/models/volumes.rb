require 'fog/openstack/models/collection'
require 'fog/openstack/compute/models/volume'

module Fog
  module OpenStack
    class Compute
      class Volumes < Fog::OpenStack::Collection
        model Fog::OpenStack::Compute::Volume

        def all(options = true)
          if !options.kind_of?(Hash)
            if options
              Fog::Logger.deprecation('Calling OpenStack[:compute].volumes.all(true) is deprecated, use .volumes.all')
            else
              Fog::Logger.deprecation('Calling OpenStack[:compute].volumes.all(false) is deprecated, use .volumes.summary')
            end
            load_response(service.list_volumes(options), 'volumes')
          else
            load_response(service.list_volumes_detail(options), 'volumes')
          end
        end

        def summary(options = {})
          load_response(service.list_volumes(options), 'volumes')
        end

        def get(volume_id)
          if volume = service.get_volume_details(volume_id).body['volume']
            new(volume)
          end
        rescue Fog::OpenStack::Compute::NotFound
          nil
        end
      end
    end
  end
end
