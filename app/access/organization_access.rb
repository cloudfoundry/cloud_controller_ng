module VCAP::CloudController
  class OrganizationAccess < BaseAccess
    def create?(_org, _params=nil)
      return true if context.queryer.can_write_globally?

      FeatureFlag.enabled?(:user_org_creation)
    end

    def read_for_update?(org, params=nil)
      return true if context.queryer.can_write_globally?
      return false unless org.active?
      return false unless context.queryer.can_write_to_active_org?(org.id)

      return false if params.present? && (params.key?(:quota_definition_guid.to_s) || params.key?(:billing_enabled.to_s))

      true
    end

    def can_remove_related_object?(org, params={})
      return true if context.queryer.can_write_globally?

      user_acting_on_themselves = user_acting_on_themselves?(params)
      return false unless context.queryer.can_write_to_active_org?(org.id) || user_acting_on_themselves
      return false unless org.active?

      validate!(org, params)

      user_acting_on_themselves || read_for_update?(org, params)
    end

    def update?(org, _params=nil)
      return true if context.queryer.can_write_globally?
      return false unless org.active?

      context.queryer.can_write_to_active_org?(org.id)
    end

    def delete?(_object)
      context.queryer.can_write_globally?
    end

    def index?(_, _params=nil)
      admin_user? || admin_read_only_user? || has_read_scope? || global_auditor?
    end

    def read_with_token?(_)
      admin_user? || admin_read_only_user? || has_read_scope? || global_auditor?
    end

    def create_with_token?(_)
      admin_user? || has_write_scope?
    end

    def read_for_update_with_token?(_)
      admin_user? || has_write_scope?
    end

    def can_remove_related_object_with_token?(*)
      read_for_update_with_token?(*)
    end

    def read_related_object_for_update_with_token?(*)
      read_for_update_with_token?(*)
    end

    def update_with_token?(_)
      admin_user? || has_write_scope?
    end

    def delete_with_token?(_)
      admin_user? || has_write_scope?
    end

    def index_with_token?(_)
      admin_user? || admin_read_only_user? || has_read_scope? || global_auditor?
    end

    private

    def user_acting_on_themselves?(options)
      %i[auditors billing_managers managers users].include?(options[:relation]) && context.user&.guid == options[:related_guid]
    end

    def validate!(org, params)
      validate_remove_billing_manager_by_guid!(org) if params[:relation] == :billing_managers
      validate_remove_manager_by_guid!(org) if params[:relation] == :managers
      validate_remove_user_by_guid!(org, params[:related_guid]) if params[:relation] == :users
    end

    def validate_remove_billing_manager_by_guid!(org)
      return if org.billing_managers_dataset.count > 1

      raise CloudController::Errors::ApiError.new_from_details('LastBillingManagerInOrg')
    end

    def validate_remove_manager_by_guid!(org)
      return if org.managers_dataset.count > 1

      raise CloudController::Errors::ApiError.new_from_details('LastManagerInOrg')
    end

    def validate_remove_user_by_guid!(org, user_guid)
      raise CloudController::Errors::ApiError.new_from_details('LastManagerInOrg') if org.managers_dataset.count == 1 && org.managers.first.guid == user_guid

      raise CloudController::Errors::ApiError.new_from_details('LastBillingManagerInOrg') if org.billing_managers_dataset.count == 1 && org.billing_managers.first.guid == user_guid

      return unless org.users_dataset.count == 1 && org.users.first.guid == user_guid && org.managers_dataset.count <= 1 && org.billing_managers_dataset.count <= 1

      raise CloudController::Errors::ApiError.new_from_details('LastUserInOrg')
    end
  end
end
