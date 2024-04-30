Sequel.migration do
  no_transaction # to use the 'concurrently' option

  up do
    VCAP::Migration.with_concurrent_timeout(self) do
      add_index :service_plan_visibilities, :service_plan_id, name: :spv_service_plan_id_index, concurrently: true if database_type == :postgres
    end
  end

  down do
    VCAP::Migration.with_concurrent_timeout(self) do
      drop_index :service_plan_visibilities, nil, name: :spv_service_plan_id_index, concurrently: true if database_type == :postgres
    end
  end
end
