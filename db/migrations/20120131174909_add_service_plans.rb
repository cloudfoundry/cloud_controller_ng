# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    create_table :service_plans do
      primary_key :id

      String :name,           :null => false
      String :description,    :null => false

      foreign_key :service_id, :services, :null => false

      Timestamp :created_at, :null => false
      Timestamp :updated_at

      index [:service_id, :name], :unique => true
    end
  end
end
