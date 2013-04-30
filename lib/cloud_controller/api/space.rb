# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :Space do
    permissions_required do
      full Permissions::CFAdmin
      full Permissions::OrgManager
      read   Permissions::SpaceManager
      update Permissions::SpaceManager
      read Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    define_attributes do
      attribute  :name,            String
      to_one     :organization
      to_many    :developers
      to_many    :managers
      to_many    :auditors
      to_many    :apps
      to_many    :domains
      to_many    :service_instances
    end

    query_parameters :name, :organization_guid, :developer_guid, :app_guid

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on([:organization_id, :name])
      if name_errors && name_errors.include?(:unique)
        Errors::SpaceNameTaken.new(attributes["name"])
      else
        Errors::SpaceInvalid.new(e.errors.full_messages)
      end
    end


    def enumerate_crashes_by_space(space_guid)
      find_id_and_validate_access(:read, space_guid)

      options = {
        :start_time => parse_date_param("start_date"),
        :end_time => parse_date_param("end_date")
      }

      ds = Models::CrashEvent.find_by_space(space_guid, options)
      RestController::Paginator.render_json(VCAP::CloudController.controller_from_name("CrashEvent"), ds, self.class.path,
        @opts.merge(:serialization => RestController::EntityOnlyObjectSerialization, :order_by => :timestamp))
    end

    get "/v2/spaces/:guid/crash_events", :enumerate_crashes_by_space
  end
end
