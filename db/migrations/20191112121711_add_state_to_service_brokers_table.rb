Sequel.migration do
  change do
    alter_table :service_brokers do
      add_column :state, String, size: 255, default: '', allow_null: false
    end
  end
end
