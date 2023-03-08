Sequel.migration do
  change do
    alter_table :services do
      add_index :service_broker_id, name: :services_service_broker_id_index
    end
  end
end
