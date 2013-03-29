# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :services do
      add_column :unique_id, String
      add_index :unique_id, unique: true
    end

    if self.class.name.match /mysql/i
      run "UPDATE services SET unique_id=CONCAT(provider,  '_', label)"
    else
      run "UPDATE services SET unique_id=(provider || '_' || label)"
    end

    alter_table :services do
      set_column_allow_null :unique_id, false
    end
  end
end
