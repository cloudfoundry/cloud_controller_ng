require 'fog/openstack/models/collection'
require 'fog/openstack/network/models/extension'

module Fog
  module OpenStack
    class Network
      class Extensions < Fog::OpenStack::Collection
        attribute :filters

        model Fog::OpenStack::Network::Extension

        def initialize(attributes)
          self.filters ||= {}
          super
        end

        def all(filters_arg = filters)
          filters = filters_arg
          load_response(service.list_extensions(filters), 'extensions')
        end

        def get(extension_id)
          if extension = service.get_extension(extension_id).body['extension']
            new(extension)
          end
        rescue Fog::OpenStack::Network::NotFound
          nil
        end
      end
    end
  end
end
