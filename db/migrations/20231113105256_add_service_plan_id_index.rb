Sequel.migration do
  no_transaction # to use the 'concurrently' option

  up do
    add_index :service_plan_visibilities, :service_plan_id, name: :spv_service_plan_id_index, concurrently: true if database_type == :postgres
  end

  down do
    drop_index :service_plan_visibilities, nil, name: :spv_service_plan_id_index, concurrently: true if database_type == :postgres
  end
end
