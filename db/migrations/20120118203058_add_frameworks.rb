# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    create_table :frameworks do
      primary_key :id

      String :name,           :null => false
      String :description,    :null => false

      Timestamp :created_at,  :null => false
      Timestamp :updated_at

      index :name, :unique => true
    end
  end
end
