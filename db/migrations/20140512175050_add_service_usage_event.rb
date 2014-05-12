Sequel.migration do
  change do
    create_table :service_usage_events do
      primary_key :id
      VCAP::Migration.guid(self, nil)
      Timestamp :created_at, null: false
      index :created_at, name: "service usage_events_created_at_index".to_sym
      String :state, null: false
      String :org_guid, null: false
      String :space_guid, null: false
      String :space_name, null: false
      String :service_instance_guid, null: false
      String :service_instance_name, null: false
      String :service_plan_guid, null: false
      String :service_plan_name, null: false
      String :service_guid, null: false
      String :service_label, null: false
    end
  end
end
