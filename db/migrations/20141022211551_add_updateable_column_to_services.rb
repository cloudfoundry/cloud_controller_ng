Sequel.migration do
  change do
    add_column :services, :plan_updateable, TrueClass, default: false
  end
end
