require 'fog/openstack/models/collection'
require 'fog/openstack/compute/models/key_pair'

module Fog
  module OpenStack
    class Compute
      class KeyPairs < Fog::OpenStack::Collection
        model Fog::OpenStack::Compute::KeyPair

        def all(options = {})
          items = []
          service.list_key_pairs(options).body['keypairs'].each do |kp|
            items += kp.values
          end
          # TODO: convert to load_response?
          load(items)
        end

        def get(key_pair_name)
          if key_pair_name
            all.select { |kp| kp.name == key_pair_name }.first
          end
        rescue Fog::OpenStack::Compute::NotFound
          nil
        end
      end
    end
  end
end
