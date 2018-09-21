Sequel.migration do
  up do
    alter_table :services do
      drop_index :unique_id
      add_index :unique_id, name: :services_unique_id_index, unique: false
    end
  end

  down do
    alter_table :services do
      drop_index :unique_id
      add_index :unique_id, name: :services_unique_id_index, unique: true
    end
  end
end
