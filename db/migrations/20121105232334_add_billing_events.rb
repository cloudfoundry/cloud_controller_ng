# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    # rather than creating different tables for each type of events, we're
    # going to denormalize them into one table.
    #
    # We don't use foreign keys here because the objects may get deleted after
    # the billing records are generated, and that should be allowed.
    create_table :billing_events do
      VCAP::Migration.common(self)
      Timestamp :timestamp, :null => false, :index => true
      String :kind, :null => false
      String :organization_guid, :null => false
      String :organization_name, :null => false
      String :space_guid
      String :space_name
      String :app_guid
      String :app_name
      String :app_plan_name
      String :app_run_id
      Integer :app_memory
      Integer :app_instance_count
      String :service_instance_guid
      String :service_instance_name
      String :service_guid
      String :service_label
      String :service_provider
      String :service_version
      String :service_plan_guid
      String :service_plan_name
    end
  end
end
