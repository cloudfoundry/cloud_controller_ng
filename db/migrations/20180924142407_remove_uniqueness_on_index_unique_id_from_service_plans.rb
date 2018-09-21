Sequel.migration do
  up do
    alter_table :service_plans do
      drop_index :unique_id
      add_index :unique_id, name: :service_plans_unique_id_index, unique: false
    end
  end

  down do
    alter_table :service_plans do
      drop_index :unique_id
      add_index :unique_id, name: :service_plans_unique_id_index, unique: true
    end
  end
end
