# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    create_table :service_instances do
      primary_key :id

      String :name,           :null => false, :index => true

      # the creds are needed for bacwkards compatability, but,
      # they should be deprecated in place of bindings only
      String :credentials, :null => false
      String :vendor_data

      foreign_key :app_space_id,    :app_spaces,        :null => false
      foreign_key :service_plan_id, :service_plans,     :null => false

      Timestamp :created_at, :null => false
      Timestamp :updated_at

      index [:app_space_id, :name], :unique => true
    end
  end
end
