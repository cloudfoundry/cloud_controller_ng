# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    # sqlite referencial integrity doesn't seem to work if you change
    # constraints on a table, which we are doing with the domains table.
    # Since we still in development/testing, we can just drop the table and
    # recreate it.
    #
    # Postgres isn't cool with this, but probably would have allowed for just
    # chaging the constraint.  We drop and recreate all related tables so that
    # we can push to the integration environment.  At this point in time, that
    # is fine, but clearly we wouldn't be able to do this once out of
    # initial dev/test.
    drop_table :apps_routes
    drop_table :routes
    drop_table :domains_spaces
    drop_table :domains

    create_table :domains do
      VCAP::Migration.common(self)

      String :name, :null => false, :unique => true
      foreign_key :owning_organization_id, :organizations
    end

    create_table :domains_spaces do
      foreign_key :space_id, :spaces, :null => false
      foreign_key :domain_id, :domains, :null => false

      index [:space_id, :domain_id], :unique => true
    end

    create_table :domains_organizations do
      foreign_key :domain_id, :domains, :null => false
      foreign_key :organization_id, :organizations, :null => false
      index [:domain_id, :organization_id], :unique => true
    end

    create_table :routes do
      VCAP::Migration.common(self)

      # TODO: this is semi temporary and will be fully thought through when
      # we do custom domains.  For now, this "works" and will prevent
      # collisions.
      String :host, :null => false
      foreign_key :domain_id, :domains, :null => false
      index [:host, :domain_id], :unique => true
    end

    create_table :apps_routes do
      foreign_key :app_id, :apps, :null => false
      foreign_key :route_id, :routes, :null => false
      index [:app_id, :route_id], :unique => true
    end
  end
end
