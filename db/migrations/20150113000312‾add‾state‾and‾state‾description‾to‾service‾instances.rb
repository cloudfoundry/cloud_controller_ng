Sequel.migration do
  change do
    add_column :service_instances, :state, String
    add_column :service_instances, :state_description, String, text: true
  end
end
