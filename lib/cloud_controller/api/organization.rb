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
      to_one    :quota_definition, :optional_in => :create
      to_many   :spaces, :exclude_in => :create
      to_many   :domains
      to_many   :users
      to_many   :managers
      to_many   :billing_managers
      to_many   :auditors
    end

    query_parameters :name, :space_guid,
                     :user_guid, :manager_guid, :billing_manager_guid,
                     :auditor_guid

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)
      if name_errors && name_errors.include?(:unique)
        Errors::OrganizationNameTaken.new(attributes["name"])
      else
        Errors::OrganizationInvalid.new(e.errors.full_messages)
      end
    end

    def enumerate_crashes_by_org(org_guid)
      find_id_and_validate_access(:read, org_guid)

      options = {
        :start_time => parse_date_param("start_date"),
        :end_time => parse_date_param("end_date")
      }

      ds = Models::CrashEvent.find_by_org(org_guid, options)
      RestController::Paginator.render_json(VCAP::CloudController.controller_from_name("CrashEvent"), ds, self.class.path,
        @opts.merge(:serialization => RestController::EntityOnlyObjectSerialization, :order_by => :timestamp))
    end

    get "/v2/organizations/:guid/crash_events", :enumerate_crashes_by_org
  end
end
