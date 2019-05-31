Sequel.migration do
  change do
    add_column :service_instances, :maintenance_info, :text, null: true
  end
end
