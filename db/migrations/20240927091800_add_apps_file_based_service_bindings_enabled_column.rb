Sequel.migration do
  change do
    add_column :apps, :file_based_service_bindings_enabled, :boolean, default: false, null: false
  end
end
