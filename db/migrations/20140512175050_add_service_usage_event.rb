Sequel.migration do
  change do
    create_table :service_usage_events do
      primary_key :id
      VCAP::Migration.guid(self, 'usage_events')
      DateTime :created_at, null: false
      index :created_at, name: 'created_at_index'.to_sym
      String :state, null: false
      String :org_guid, null: false
      String :space_guid, null: false
      String :space_name, null: false
      String :service_instance_guid, null: false
      String :service_instance_name, null: false
      String :service_instance_type, null: false
      String :service_plan_guid, null: true
      String :service_plan_name, null: true
      String :service_guid, null: true
      String :service_label, null: true
    end
  end
end
