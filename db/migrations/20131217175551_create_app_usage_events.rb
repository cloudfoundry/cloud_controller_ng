Sequel.migration do
  change do
    create_table :app_usage_events do
      primary_key :id
      VCAP::Migration.guid(self, nil)
      DateTime :created_at, null: false
      index :created_at, name: 'usage_events_created_at_index'.to_sym
      Integer :instance_count, null: false
      Integer :memory_in_mb_per_instance, null: false
      String :state, null: false
      String :app_guid, null: false
      String :app_name, null: false
      String :space_guid, null: false
      String :space_name, null: false
      String :org_guid, null: false
    end
  end
end
