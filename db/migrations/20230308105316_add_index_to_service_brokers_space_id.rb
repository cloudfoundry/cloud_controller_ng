Sequel.migration do
  change do
    alter_table :service_brokers do
      add_index :space_id, name: :service_brokers_space_id_index
    end
  end
end
