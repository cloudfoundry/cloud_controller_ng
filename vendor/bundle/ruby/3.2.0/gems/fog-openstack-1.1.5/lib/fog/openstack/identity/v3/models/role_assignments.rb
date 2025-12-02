require 'fog/openstack/models/collection'
require 'fog/openstack/identity/v3/models/role'

module Fog
  module OpenStack
    class Identity
      class V3
        class RoleAssignments < Fog::OpenStack::Collection
          model Fog::OpenStack::Identity::V3::RoleAssignment

          def all(options = {})
            load_response(service.list_role_assignments(options), 'role_assignments')
          end

          def filter_by(options = {})
            Fog::Logger.deprecation("Calling OpenStack[:keystone].role_assignments.filter_by(options) method which"\
                                    " is not part of standard interface and is deprecated, call "\
                                    " .role_assignments.all(options) or .role_assignments.summary(options) instead.")
            all(options)
          end
        end
      end
    end
  end
end
