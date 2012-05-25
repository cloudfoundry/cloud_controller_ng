# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    create_table(:service_bindings) do
      primary_key :id
      String :guid, :null => false, :index => true

      String :credentials, :null => false
      String :binding_options
      String :vendor_data

      foreign_key :app_id, :apps, :null => false
      foreign_key :service_instance_id, :service_instances, :null => false

      Timestamp :created_at, :null => false
      Timestamp :updated_at

      index [:app_id, :service_instance_id], :unique => true
    end
  end
end
