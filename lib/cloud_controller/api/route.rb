# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :Route do
    permissions_required do
      full Permissions::CFAdmin
      full Permissions::OrgManager
      read Permissions::Auditor
      full Permissions::SpaceManager
      full Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    define_attributes do
      attribute :host, String
      to_one    :domain
    end

    query_parameters :host, :domain_guid

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on([:host, :domain_id])
      if name_errors && name_errors.include?(:unique)
        RouteHostTaken.new(attributes["host"])
      else
        RouteInvalid.new(e.errors.full_messages)
      end
    end
  end
end
