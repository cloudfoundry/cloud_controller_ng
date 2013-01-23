# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :frameworks do
      set_column_not_null :internal_info

      # Redo all constraints because SQLite has a bug
      # when adding new constraint to the table
      if @db.kind_of?(Sequel::SQLite::Database)
        set_column_not_null :name
        add_unique_constraint :name
        set_column_not_null :description
      end
    end
  end
end
