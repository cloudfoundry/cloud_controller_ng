module VCAP::CloudController
  class SpaceAccess < BaseAccess
    def create?(space, params=nil)
      return true if admin_user?
      return false if space.in_suspended_org?
      space.organization.managers.include?(context.user)
    end

    def can_remove_related_object?(space, params)
      return true if admin_user?
      user_acting_on_themselves?(params) || super
    end

    def read_for_update?(space, params=nil)
      return true if admin_user?
      return false if space.in_suspended_org?
      space.organization.managers.include?(context.user) || space.managers.include?(context.user)
    end

    def update?(space, params=nil)
      read_for_update?(space, params)
    end

    def delete?(space)
      create?(space)
    end

    private

    def user_acting_on_themselves?(options)
      [:auditors, :developers, :managers].include?(options[:relation]) && context.user.guid == options[:related_guid]
    end
  end
end
