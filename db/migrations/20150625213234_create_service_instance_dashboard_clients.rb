Sequel.migration do
  change do
    create_table :service_instance_dashboard_clients do
      primary_key :id

      VCAP::Migration.timestamps(self, 's_i_d_clients')

      String :uaa_id, null: false
      Integer :managed_service_instance_id

      index :uaa_id, unique: true, name: 's_i_d_clients_uaa_id_unique'
      index :managed_service_instance_id, name: 'svc_inst_dash_cli_svc_inst_id_idx'
    end
  end
end
