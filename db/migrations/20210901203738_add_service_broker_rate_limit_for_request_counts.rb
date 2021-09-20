Sequel.migration do
  change do
    alter_table :request_counts do
      add_column :service_instance_count, Integer, default: 0
      add_column :service_instance_valid_until, Time
    end
  end
end
