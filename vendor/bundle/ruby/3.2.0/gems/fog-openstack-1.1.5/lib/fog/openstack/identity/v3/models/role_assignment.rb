require 'fog/openstack/models/model'

module Fog
  module OpenStack
    class Identity
      class V3
        class RoleAssignment < Fog::OpenStack::Model
          attribute :scope
          attribute :role
          attribute :user
          attribute :group
          attribute :links

          def to_s
            links['assignment']
          end
        end
      end
    end
  end
end
