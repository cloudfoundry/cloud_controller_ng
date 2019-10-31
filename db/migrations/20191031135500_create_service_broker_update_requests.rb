Sequel.migration do
  change do
    create_table(:service_broker_update_requests) do
      VCAP::Migration.common(self)

      String :name
      String :broker_url
      String :authentication
      String :salt, size: 255
      String :encryption_key_label, size: 255
      Integer :encryption_iterations, default: 2048, null: false

      Integer :service_broker_id, null: false
      foreign_key :service_broker_id, :service_brokers, name: :fk_service_brokers_id
    end
  end
end
