Sequel.migration do
  change do
    alter_table :service_instances do
      add_index :gateway_name
    end
  end
end
