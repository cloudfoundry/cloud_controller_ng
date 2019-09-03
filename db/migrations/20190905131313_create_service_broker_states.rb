Sequel.migration do
  change do
    create_table(:service_broker_states) do
      VCAP::Migration.common(self)

      String :state, size: 50, null: false

      Integer :service_broker_id, null: false
      foreign_key :service_broker_id, :service_brokers, name: :fk_service_brokers_id
      index [:service_broker_id], name: :fk_service_brokers_id_index
    end
  end
end
