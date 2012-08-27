# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    # sqlite referencial integrity doesn't seem to work if you change
    # constraints on a table, which we are doing with the domains table.
    # Since we still in development/testing, we can just drop the table and
    # recreate it
    drop_table :domains

    create_table :domains do
      VCAP::Migration.common(self)

      String :name, :null => false, :unique => true
      foreign_key :owning_organization_id, :organizations
    end

    create_table :domains_organizations do
      foreign_key :domain_id, :domains, :null => false
      foreign_key :organization_id, :organizations, :null => false
      index [:domain_id, :organization_id], :unique => true
    end
  end
end
