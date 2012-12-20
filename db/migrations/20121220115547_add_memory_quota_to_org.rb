# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :organizations do
      add_foreign_key :memory_quota_definition_id, :memory_quota_definitions
    end

    if self[:organizations].count > 0
      default_quota = self[:memory_quota_definitions][:name => "free"]
      unless default_quota
        id = self[:memory_quota_definitions].insert(
          :guid => SecureRandom.uuid,
          :created_at => Time.now,
          :name => "free",
          :free_limit => 1024,
          :paid_limit => 0
        )
        default_quota = self[:memory_quota_definitions][:id => id]
      end
    end

    self[:organizations].all do |r|
      self[:organizations].filter(:id => r[:id]).
        update(:memory_quota_definition_id => default_quota[:id])
    end

    alter_table :organizations do
      set_column_not_null :memory_quota_definition_id

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
