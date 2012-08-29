# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    drop_table :apps_routes
    drop_table :routes

    create_table :routes do
      VCAP::Migration.common(self)

      # TODO: this is semi temporary and will be fully thought through when
      # we do custom domains.  For now, this "works" and will prevent
      # collisions.
      String :host, :null => false
      foreign_key :domain_id, :domains, :null => false
      foreign_key :organization_id, :organizations, :null => false
      index [:host, :domain_id], :unique => true
    end

    create_table :apps_routes do
      foreign_key :app_id, :apps, :null => false
      foreign_key :route_id, :routes, :null => false
      index [:app_id, :route_id], :unique => true
    end
  end
end
