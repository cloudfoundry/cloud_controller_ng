module VCAP::CloudController
  class Membership
    def initialize(user)
      @user = user
    end

    def spaces(roles: [])
      return Space.dataset if @user.admin?
      roles.map do |role|
        case role
        when :developer
          @user.spaces_dataset.association_join(:organization).where(organization__status: 'active')
        end
      end.reduce(&:union)
    end

    def space_role?(role, space_guid)
      return true if @user.admin?
      spaces(roles: [role]).where(:"#{Space.table_name}__guid" => space_guid).limit(1).count > 0
    end
  end
end
