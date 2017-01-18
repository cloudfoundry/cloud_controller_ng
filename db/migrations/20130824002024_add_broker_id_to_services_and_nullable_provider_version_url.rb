Sequel.migration do
  change do
    alter_table :services do
      add_column :service_broker_id, Integer
      add_foreign_key [:service_broker_id], :service_brokers, name: :fk_services_service_broker_id

      drop_index [:label, :provider]
      set_column_allow_null :provider
      add_index [:label, :provider]

      set_column_allow_null :version
      set_column_allow_null :url
    end
  end
end
