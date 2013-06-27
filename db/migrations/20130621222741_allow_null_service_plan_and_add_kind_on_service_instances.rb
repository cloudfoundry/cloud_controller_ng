Sequel.migration do
  change do
    alter_table :service_instances do
      set_column_allow_null :service_plan_id
      add_column :kind, String, null: false, default: 'VCAP::CloudController::Models::ManagedServiceInstance'
    end
  end
end
