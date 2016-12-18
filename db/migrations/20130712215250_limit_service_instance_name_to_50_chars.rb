Sequel.migration do
  up do
    alter_table :service_instances do
      drop_index :name
      drop_index [:space_id, :name]
      set_column_type :name, 'varchar(50)'
      add_index :name
      add_index [:space_id, :name], unique: true
    end
  end

  down do
    alter_table :service_instances do
      drop_index :name
      drop_index [:space_id, :name]
      set_column_type :name, String
      add_index :name
      add_index [:space_id, :name], unique: true
    end
  end
end
