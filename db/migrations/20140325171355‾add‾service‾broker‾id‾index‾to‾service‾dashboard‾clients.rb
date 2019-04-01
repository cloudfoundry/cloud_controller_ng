Sequel.migration do
  up do
    alter_table :service_dashboard_clients do
      set_column_allow_null :service_broker_id
      add_index :service_broker_id, name: :svc_dash_cli_svc_brkr_id_idx
    end
  end

  down do
    run <<-SQL
      DELETE FROM service_dashboard_clients WHERE service_broker_id IS NULL
    SQL

    alter_table :service_dashboard_clients do
      set_column_allow_null :service_broker_id, false
      drop_index :service_broker_id, name: :svc_dash_cli_svc_brkr_id_idx
    end
  end
end
