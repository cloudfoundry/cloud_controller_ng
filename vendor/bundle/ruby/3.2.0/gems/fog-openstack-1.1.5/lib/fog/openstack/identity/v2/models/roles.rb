require 'fog/openstack/models/collection'
require 'fog/openstack/identity/v2/models/role'

module Fog
  module OpenStack
    class Identity
      class V2
        class Roles < Fog::OpenStack::Collection
          model Fog::OpenStack::Identity::V2::Role

          def all(options = {})
            load_response(service.list_roles(options), 'roles')
          end

          def get(id)
            service.get_role(id)
          end
        end
      end
    end
  end
end
