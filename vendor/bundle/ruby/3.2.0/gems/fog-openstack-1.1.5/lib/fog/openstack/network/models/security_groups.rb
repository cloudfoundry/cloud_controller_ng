require 'fog/openstack/models/collection'
require 'fog/openstack/network/models/security_group'

module Fog
  module OpenStack
    class Network
      class SecurityGroups < Fog::OpenStack::Collection
        attribute :filters

        model Fog::OpenStack::Network::SecurityGroup

        def initialize(attributes)
          self.filters ||= {}
          super
        end

        def all(filters_arg = filters)
          filters = filters_arg
          load_response(service.list_security_groups(filters), 'security_groups')
        end

        def get(security_group_id)
          if security_group = service.get_security_group(security_group_id).body['security_group']
            new(security_group)
          end
        rescue Fog::OpenStack::Network::NotFound
          nil
        end
      end
    end
  end
end
