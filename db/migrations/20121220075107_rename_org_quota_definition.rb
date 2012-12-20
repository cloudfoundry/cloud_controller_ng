# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :organizations do
      add_foreign_key :service_instances_quota_definition_id, :service_instances_quota_definitions
    end

    self[:organizations].all do |r|
      self[:organizations].filter(:id => r[:id]).
        update(:service_instances_quota_definition_id => r[:quota_definition_id])
    end

    alter_table :organizations do
      drop_column :quota_definition_id
      set_column_not_null :service_instances_quota_definition_id

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
