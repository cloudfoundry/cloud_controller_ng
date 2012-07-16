# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :Domain do
    permissions_required do
      full Permissions::CFAdmin
      full Permissions::OrgManager
      read Permissions::SpaceManager
      read Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    define_attributes do
      attribute :name, String
      to_one    :organization
    end

    query_parameters :name, :organization_guid, :space_guid

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)
      if name_errors && name_errors.include?(:unique)
        OrganizationNameTaken.new(attributes["name"])
      else
        OrganizationInvalid.new(e.errors.full_messages)
      end
    end
  end
end
