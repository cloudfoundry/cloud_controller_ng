# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :User do
    permissions_required do
      full Permissions::CFAdmin
    end

    define_attributes do
      attribute :guid, :exclude_in => :update
      to_many   :app_spaces
      to_many   :organizations
      to_many   :managed_organizations
      to_many   :billing_managed_organizations
      to_many   :audited_organizations
      to_many   :managed_app_spaces
      to_many   :audited_app_spaces
      attribute :admin, Message::Boolean
      to_one    :default_app_space
    end

    query_parameters :app_space_guid, :organization_guid,
                     :managed_organization_guid,
                     :billing_managed_organization_guid,
                     :audited_organization_guid,
                     :managed_app_space_guid,
                     :audited_app_space_guid

    def self.translate_validation_exception(e, attributes)
      guid_errors = e.errors.on(:guid)
      if guid_errors && guid_errors.include?(:unique)
        UaaIdTaken.new(attributes["guid"])
      else
        UserInvalid.new(e.errors.full_messages)
      end
    end
  end
end
