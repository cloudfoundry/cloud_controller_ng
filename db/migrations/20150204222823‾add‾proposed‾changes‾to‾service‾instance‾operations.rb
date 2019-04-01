Sequel.migration do
  change do
    alter_table :service_instance_operations do
      add_column :proposed_changes, String, null: false, default: '{}'
    end
  end
end
