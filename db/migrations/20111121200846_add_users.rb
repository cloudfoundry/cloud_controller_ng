# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    create_table :users do
      String :id, :null => false, :primary_key => true

      Boolean :admin,            :default => false
      Boolean :active,           :default => false

      Timestamp :created_at,     :null => false
      Timestamp :updated_at
    end
  end
end
