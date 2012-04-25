# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    create_table :organizations do
      primary_key :id

      String :name, :null => false, :index => true, :unique => true

      Timestamp :created_at, :null => false
      Timestamp :updated_at
    end
  end
end
