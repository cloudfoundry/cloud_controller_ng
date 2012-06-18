# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :AppSpace do
    permissions_required do
      full Permissions::CFAdmin
      full Permissions::OrgManager
      read   Permissions::AppSpaceManager
      update Permissions::AppSpaceManager
      read Permissions::AppSpaceDeveloper
      read Permissions::AppSpaceAuditor
    end

    define_attributes do
      attribute  :name,            String
      to_one     :organization
      to_many    :developers
      to_many    :managers
      to_many    :auditors
      to_many    :apps
    end

    query_parameters :organization_guid, :developer_guid, :app_guid

    def enumeration_filter
      { :developers => [@user],
        :managers => [@user],
        :auditors => [@user]
      }.sql_or
    end

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on([:organization_id, :name])
      if name_errors && name_errors.include?(:unique)
        AppSpaceNameTaken.new(attributes["name"])
      else
        AppSpaceInvalid.new(e.errors.full_messages)
      end
    end
  end
end
