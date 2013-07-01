Sequel.migration do
  change do
    alter_table(:service_instances) do
      add_column :is_gateway_service, TrueClass, default: true, null: false
    end
  end
end
