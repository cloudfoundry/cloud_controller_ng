# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :Organization do
    permissions_required do
      full Permissions::CFAdmin
      read Permissions::OrgManager
      update Permissions::OrgManager
      read Permissions::OrgUser
      read Permissions::BillingManager
      read Permissions::Auditor
    end

    define_attributes do
      attribute :name, String
      attribute :billing_enabled, Message::Boolean, :default => false
      attribute :can_access_non_public_plans, Message::Boolean, :default => false
      attribute :status, String, :default => 'active'
      to_one    :quota_definition, :optional_in => :create
      to_many   :spaces, :exclude_in => :create
      to_many   :domains
      to_many   :users
      to_many   :managers
      to_many   :billing_managers
      to_many   :auditors
      to_many   :app_events
    end

    query_parameters :name, :space_guid, :user_guid,
                    :manager_guid, :billing_manager_guid,
                    :auditor_guid, :status

    def self.translate_validation_exception(e, attributes)
      quota_def_errors = e.errors.on(:quota_definition_id)
      name_errors = e.errors.on(:name)
      if quota_def_errors && quota_def_errors.include?(:not_authorized)
        Errors::NotAuthorized.new(attributes["quota_definition_id"])
      elsif name_errors && name_errors.include?(:unique)
        Errors::OrganizationNameTaken.new(attributes["name"])
      else
        Errors::OrganizationInvalid.new(e.errors.full_messages)
      end
    end
  end
end
