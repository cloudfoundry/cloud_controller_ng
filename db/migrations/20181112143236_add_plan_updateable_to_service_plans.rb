Sequel.migration do
  change do
    add_column :service_plans, :plan_updateable, TrueClass, null: true
  end
end
