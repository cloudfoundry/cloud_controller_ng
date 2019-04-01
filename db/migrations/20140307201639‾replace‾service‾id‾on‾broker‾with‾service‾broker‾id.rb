Sequel.migration do
  up do
    alter_table :service_dashboard_clients do
      add_column :service_broker_id, Integer
    end
    run <<-SQL
      UPDATE service_dashboard_clients
        SET service_broker_id = (
          SELECT services.service_broker_id
            FROM services
            WHERE services.unique_id = service_dashboard_clients.service_id_on_broker
          )
    SQL
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
