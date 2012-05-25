# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    create_table :app_spaces do
      primary_key :id
      String :guid, :null => false, :index => true

      String :name, :null => false

      foreign_key :organization_id, :organizations, :null => false

      Timestamp :created_at, :null => false
      Timestamp :updated_at

      index [:organization_id, :name], :unique => true
    end
  end
end
