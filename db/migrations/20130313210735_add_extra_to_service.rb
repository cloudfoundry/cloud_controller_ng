# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :services do
      if Sequel::Model.db.database_type == :mssql
        add_column :extra, String, size: :max
      else
        add_column :extra, String, text: true
      end
    end
  end
end
