Sequel.migration do
  change do
    alter_table :service_instance_operations do
      add_column :broker_provided_operation, String, text: true
    end
  end
end
