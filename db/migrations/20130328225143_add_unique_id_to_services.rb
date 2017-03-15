# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :services do
      add_column :unique_id, String
      add_index :unique_id, unique: true
    end

    if self.class.name =~ /mysql/i
      run "UPDATE services SET unique_id=CONCAT(provider,  '_', label)"
    elsif Sequel::Model.db.database_type == :mssql
      run "UPDATE SERVICES SET UNIQUE_ID=CONCAT(PROVIDER,  '_', LABEL)"
    else
      run "UPDATE services SET unique_id=(provider || '_' || label)"
    end

    alter_table :services do
      drop_index :unique_id
      set_column_allow_null :unique_id, false
      add_index :unique_id, unique: true
    end
  end
end
