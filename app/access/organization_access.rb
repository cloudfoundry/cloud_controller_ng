module VCAP::CloudController
  class OrganizationAccess < BaseAccess
    def create?(org, params=nil)
      return true if admin_user?
      FeatureFlag.enabled?(:user_org_creation)
    end

    def read_for_update?(org, params=nil)
      return true if admin_user?
      return false unless org.active?
      return false unless org.managers.include?(context.user)

      if params.present?
        return false if params.key?(:quota_definition_guid.to_s) || params.key?(:billing_enabled.to_s)
      end

      true
    end

    def can_remove_related_object?(org, params={})
      return true if admin_user?
      validate!(org, params)
      user_acting_on_themselves?(params) || super
    end

    def update?(org, params=nil)
      return true if admin_user?
      return false unless org.active?
      org.managers.include?(context.user)
    end

    private

    def user_acting_on_themselves?(options)
      [:auditors, :billing_managers, :managers, :users].include?(options[:relation]) && context.user.guid == options[:related_guid]
    end

    def validate!(org, params)
      validate_remove_billing_manager_by_guid!(org) if params[:relation] == :billing_managers
      validate_remove_manager_by_guid!(org) if params[:relation] == :managers
      validate_remove_user_by_guid!(org, params[:related_guid]) if params[:relation] == :users
    end

    def validate_remove_billing_manager_by_guid!(org)
      return if org.billing_managers.count > 1
      raise CloudController::Errors::ApiError.new_from_details('LastBillingManagerInOrg')
    end

    def validate_remove_manager_by_guid!(org)
      return if org.managers.count > 1
      raise CloudController::Errors::ApiError.new_from_details('LastManagerInOrg')
    end

    def validate_remove_user_by_guid!(org, user_guid)
      if org.managers.count == 1 && org.managers[0].guid == user_guid
        raise CloudController::Errors::ApiError.new_from_details('LastManagerInOrg')
      end

      if org.billing_managers.count == 1 && org.billing_managers[0].guid == user_guid
        raise CloudController::Errors::ApiError.new_from_details('LastBillingManagerInOrg')
      end
    end
  end
end
