Sequel.migration do
  up do
    alter_table :service_instances do
      if Sequel::Model.db.database_type == :mssql
        drop_index :name
        drop_index [:space_id, :name]
      end
      set_column_type :name, 'varchar(50)'
      if Sequel::Model.db.database_type == :mssql
        add_index :name
        add_index [:space_id, :name], unique: true
      end
    end
  end

  down do
    alter_table :service_instances do
      if Sequel::Model.db.database_type == :mssql
        drop_index :name
        drop_index [:space_id, :name]
      end
      set_column_type :name, String
      if Sequel::Model.db.database_type == :mssql
        add_index :name
        add_index [:space_id, :name], unique: true
      end
    end
  end
end
