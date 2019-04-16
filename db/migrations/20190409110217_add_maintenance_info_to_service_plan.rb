Sequel.migration do
  change do
    add_column :service_plans, :maintenance_info, :text, null: true
  end
end
