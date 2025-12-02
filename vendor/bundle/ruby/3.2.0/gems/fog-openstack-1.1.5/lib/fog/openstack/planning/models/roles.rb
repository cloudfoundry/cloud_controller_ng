require 'fog/openstack/models/collection'
require 'fog/openstack/planning/models/role'

module Fog
  module OpenStack
    class Planning
      class Roles < Fog::OpenStack::Collection
        model Fog::OpenStack::Planning::Role

        def all(options = {})
          load_response(service.list_roles(options))
        end
      end
    end
  end
end
