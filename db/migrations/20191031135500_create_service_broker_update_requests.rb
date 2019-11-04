Sequel.migration do
  change do
    create_table(:service_broker_update_requests) do
      VCAP::Migration.common(self)

      String :name, size: 255
      String :broker_url, size: 255
      String :authentication, size: 16_000
      String :salt, size: 255
      String :encryption_key_label, size: 255
      Integer :encryption_iterations, default: 2048, null: false

      Integer :service_broker_id, null: false
      foreign_key :service_broker_id, :service_brokers, name: :fk_service_brokers_id
    end
  end
end
