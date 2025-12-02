require 'fog/openstack/models/collection'
require 'fog/openstack/compute/models/security_group'

module Fog
  module OpenStack
    class Compute
      class SecurityGroups < Fog::OpenStack::Collection
        model Fog::OpenStack::Compute::SecurityGroup

        def all(options = {})
          load_response(service.list_security_groups(options), 'security_groups')
        end

        def get(security_group_id)
          if security_group_id
            new(service.get_security_group(security_group_id).body['security_group'])
          end
        rescue Fog::OpenStack::Compute::NotFound
          nil
        end
      end
    end
  end
end
