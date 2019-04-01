Sequel.migration do
  change do
    add_column :service_plans, :create_instance_schema, :text, null: true
  end
end
