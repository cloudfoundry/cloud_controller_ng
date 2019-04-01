Sequel.migration do
  change do
    add_column :service_instances, :tags, String
  end
end
