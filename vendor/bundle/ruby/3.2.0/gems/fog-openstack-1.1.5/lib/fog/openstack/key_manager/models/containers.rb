require 'fog/openstack/models/collection'
require 'fog/openstack/key_manager/models/container'

module Fog
  module OpenStack
    class KeyManager
      class Containers < Fog::OpenStack::Collection
        model Fog::OpenStack::KeyManager::Container

        def all(options = {})
          load_response(service.list_containers(options), 'containers')
        end

        def get(secret_ref)
          if secret = service.get_container(secret_ref).body
            new(secret)
          end
        rescue Fog::OpenStack::Compute::NotFound
          nil
        end

      end
    end
  end
end
