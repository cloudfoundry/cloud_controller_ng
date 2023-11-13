Sequel.migration do
  up do
    add_index :service_plan_visibilities, :service_plan_id, name: :spv_service_plan_id_index, options: [:concurrently] if database_type == :postgres
  end

  down do
    drop_index :service_plan_visibilities, nil, name: :spv_service_plan_id_index, options: [:concurrently] if database_type == :postgres
  end
end
