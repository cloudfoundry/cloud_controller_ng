# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    create_table(:organizations_billing_managers) do
      foreign_key :organization_id, :organizations, :null => false
      foreign_key :user_id, :users, :null => false

      index [:organization_id, :user_id], :unique => true
    end
  end
end
