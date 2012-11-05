# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :routes do
      drop_column :organization_id
      add_column :space_id, Integer
    end

    # use all, not each, so that we get a full dataset prior to deleting
    # things
    self[:routes].all do |r|
      apps = self[:apps_routes].filter(:route_id => r[:id])
      route = self[:routes].filter(:id => r[:id])

      if apps.count == 0
        route.delete
      else
        app_id = apps.first[:app_id]
        app = self[:apps].filter(:id => app_id).first
        space_id = app[:space_id]
        route.update(:space_id => space_id)
      end
    end

    alter_table :routes do
      set_column_not_null :space_id
    end
  end
end
