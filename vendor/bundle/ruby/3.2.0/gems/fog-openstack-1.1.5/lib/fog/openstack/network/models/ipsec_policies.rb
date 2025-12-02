require 'fog/openstack/models/collection'
require 'fog/openstack/network/models/ipsec_policy'

module Fog
  module OpenStack
    class Network
      class IpsecPolicies < Fog::OpenStack::Collection
        attribute :filters

        model Fog::OpenStack::Network::IpsecPolicy

        def initialize(attributes)
          self.filters ||= {}
          super
        end

        def all(filters_arg = filters)
          filters = filters_arg
          load_response(service.list_ipsec_policies(filters), 'ipsecpolicies')
        end

        def get(ipsec_policy_id)
          if ipsec_policy = service.get_ipsec_policy(ipsec_policy_id).body['ipsecpolicy']
            new(ipsec_policy)
          end
        rescue Fog::OpenStack::Network::NotFound
          nil
        end
      end
    end
  end
end
