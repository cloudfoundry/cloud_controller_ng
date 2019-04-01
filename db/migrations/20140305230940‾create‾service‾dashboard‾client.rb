Sequel.migration do
  change do
    create_table :service_dashboard_clients do
      primary_key :id
      VCAP::Migration.timestamps(self, 's_d_clients')
      String :service_id_on_broker, null: false
      String :uaa_id,               null: false

      index :uaa_id,               unique: true, name: 's_d_clients_uaa_id_unique'
      index :service_id_on_broker, unique: true, name: 's_d_clients_service_id_unique'
    end
  end
end
