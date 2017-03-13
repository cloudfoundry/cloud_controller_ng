Sequel.migration do
  up do
    run <<-SQL
      INSERT INTO service_dashboard_clients (uaa_id, service_id_on_broker)
        SELECT sso_client_id, unique_id
        FROM services
        WHERE sso_client_id IS NOT NULL
    SQL
    if Sequel::Model.db.database_type == :mssql
      alter_table :services do
        drop_constraint :uq_services_sso_client_id
      end
    end
    alter_table :services do
      drop_column :sso_client_id
    end
  end

  down do
    alter_table :services do
      add_column :sso_client_id, String, unique: true
    end
    run <<-SQL
      UPDATE services
        SET sso_client_id = (
          SELECT service_dashboard_clients.uaa_id
          FROM service_dashboard_clients
          WHERE services.unique_id = service_dashboard_clients.service_id_on_broker
        )
    SQL
  end
end
