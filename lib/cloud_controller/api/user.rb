# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :User do
    permissions_required do
      full Permissions::CFAdmin
    end

    define_attributes do
      attribute :guid, :exclude_in => :update
      to_many   :organizations
      to_many   :app_spaces
      attribute :admin, Message::Boolean
    end

    query_parameters :app_space_guid, :organization_guid,
                     :managed_organization_guid,
                     :billing_managed_organization_guid

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
