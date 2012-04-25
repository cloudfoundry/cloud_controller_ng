# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    create_table :users do
      primary_key :id

      String  :email,            :null => false, :index => true, :unique => true
      String  :crypted_password, :null => false
      Boolean :admin,            :default => false
      Boolean :active,           :default => false

      Timestamp :created_at,     :null => false
      Timestamp :updated_at
    end
  end
end
