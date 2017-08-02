Sequel.migration do
  change do
    add_column :service_plans, :update_instance_schema, :text, null: true
  end
end
