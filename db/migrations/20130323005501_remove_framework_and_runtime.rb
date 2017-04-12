# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    # Mysql requires us to remove foreign key constraint
    # before dropping column (errno 150). Sequel also
    # requires type=foreign_key to be present for such operations.
    if self.class.name =~ /mysql/i
      alter_table :apps do
        drop_constraint :fk_apps_framework_id, type: :foreign_key
        drop_constraint :fk_apps_runtime_id, type: :foreign_key
      end
    end

    if Sequel::Model.db.database_type == :mssql
      alter_table :apps do
        drop_constraint :fk_apps_framework_id, type: :foreign_key
        drop_constraint :fk_apps_runtime_id, type: :foreign_key
      end
    end

    alter_table :apps do
      drop_column :framework_id
      drop_column :runtime_id
    end

    drop_table :frameworks
    drop_table :runtimes
  end
end
