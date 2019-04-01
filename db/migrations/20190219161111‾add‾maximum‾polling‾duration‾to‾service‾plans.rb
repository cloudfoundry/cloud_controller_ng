Sequel.migration do
  change do
    add_column :service_plans, :maximum_polling_duration, Integer, null: true
  end
end
