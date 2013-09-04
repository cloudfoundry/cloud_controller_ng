Sequel.migration do
  up do
    drop_column :service_instances, :kind
  end

  down do
    add_column :service_instances, :kind, String, null: false, default: 'VCAP::CloudController::ManagedServiceInstance'
  end
end
