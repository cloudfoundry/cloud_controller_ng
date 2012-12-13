# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :organizations do
      add_foreign_key :quota_definition_id, :quota_definitions
    end

    if self[:organizations].count > 0
      # This is a little hacky, but asside from early beta environments, no one
      # will actually have any orgs yet, so the data migration piece of this
      # won't actually do anything
      default_quota = self[:quota_definition].filter(:name => "free")
      unless default_quota
        default_quota = self[:quota_definition].create(
          :name => "free",
          :non_basic_services_allowed => false,
          :total_services => 2
        )
      end

      self[:organizations].all do |r|
        r.update(:quota_definition_id => default_quota.id)
      end
    end

    alter_table :organizations do
      set_column_not_null :quota_definition_id

      # this is hacky, but sequel doesn't preserve db constraints for sqlite
      # when adding new ones, like we just did above.  So, re-add the unique
      # name constraint.  We should seriously consider only using PG for
      # development.
      if @db.kind_of?(Sequel::SQLite::Database)
        add_unique_constraint(:name)
      end
    end
  end
end
