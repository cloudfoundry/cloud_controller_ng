module VCAP::CloudController
  class Membership
    def initialize(user)
      @user = user
    end

    def spaces(roles: [])
      roles.map do |role|
        case role
        when :developer
          @user.spaces_dataset.association_join(:organization).where(organization__status: 'active')
        end
      end.reduce(&:union)
    end

    def space_role?(role, space_guid)
      spaces(roles: [role]).where(:"#{Space.table_name}__guid" => space_guid).limit(1).count > 0
    end
  end
end
