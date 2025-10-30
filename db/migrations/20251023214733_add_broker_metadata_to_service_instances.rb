Sequel.migration do
  change do
    alter_table :service_instances do
      add_column :broker_metadata, String, text: true
    end
  end
end
