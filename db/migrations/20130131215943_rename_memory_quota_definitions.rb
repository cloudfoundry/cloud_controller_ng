# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :quota_definitions do
      drop_column :paid_memory_limit
      rename_column :free_memory_limit, :memory_limit

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
