Sequel.migration do
  change do
    add_column :services, :plan_updateable, :boolean, default: false
  end
end
