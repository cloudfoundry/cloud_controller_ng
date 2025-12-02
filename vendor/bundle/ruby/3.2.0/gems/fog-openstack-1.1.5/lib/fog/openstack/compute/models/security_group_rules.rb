require 'fog/openstack/models/collection'
require 'fog/openstack/compute/models/security_group_rule'

module Fog
  module OpenStack
    class Compute
      class SecurityGroupRules < Fog::OpenStack::Collection
        model Fog::OpenStack::Compute::SecurityGroupRule

        def get(security_group_rule_id)
          if security_group_rule_id
            body = service.get_security_group_rule(security_group_rule_id).body
            new(body['security_group_rule'])
          end
        rescue Fog::OpenStack::Compute::NotFound
          nil
        end
      end
    end
  end
end
