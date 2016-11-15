Sequel.migration do
  change do
    add_column :service_plans, :bindable, TrueClass, null: true
  end
end
