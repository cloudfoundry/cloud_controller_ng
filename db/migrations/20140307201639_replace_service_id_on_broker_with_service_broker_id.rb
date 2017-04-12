Sequel.migration do
  up do
    alter_table :service_dashboard_clients do
      add_column :service_broker_id, Integer
    end
    if Sequel::Model.db.database_type == :mssql
      run <<-SQL
        UPDATE SERVICE_DASHBOARD_CLIENTS
          SET SERVICE_BROKER_ID = (
            SELECT SERVICES.SERVICE_BROKER_ID
              FROM SERVICES
              WHERE SERVICES.UNIQUE_ID = SERVICE_DASHBOARD_CLIENTS.SERVICE_ID_ON_BROKER
            )
      SQL
    else
      run <<-SQL
        UPDATE service_dashboard_clients
          SET service_broker_id = (
            SELECT services.service_broker_id
              FROM services
              WHERE services.unique_id = service_dashboard_clients.service_id_on_broker
            )
      SQL
    end
    alter_table :service_dashboard_clients do
      set_column_not_null :service_broker_id
      drop_index :service_id_on_broker, name: 's_d_clients_service_id_unique'
      drop_column :service_id_on_broker
    end
  end

  down do
    raise Sequel::Error.new('This migration cannot be reversed.')
  end
end
