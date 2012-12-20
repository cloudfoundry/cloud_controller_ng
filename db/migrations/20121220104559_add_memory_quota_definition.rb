# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :quota_definitions do
      add_column :free_memory_limit, Integer
      add_column :paid_memory_limit, Integer
    end

    self[:quota_definitions].all do |r|
      self[:quota_definitions].filter(:name => r[:name]).
        update(:free_memory_limit => 1024)
      self[:quota_definitions].filter(:name => r[:name]).
        update(:paid_memory_limit => 0)
    end

    alter_table :quota_definitions do
      set_column_not_null :free_memory_limit
      set_column_not_null :paid_memory_limit

      # Sequel doesn't preserve db constraints for sqlite when adding new
      # constraints, like we did just above.  So, we add the unique name
      # constraint again. We should seriously consider only using Postgres
      # for development.
      if @db.kind_of?(Sequel::SQLite::Database)
        add_unique_constraint(:name)
      end
    end
  end
end
