Sequel.migration do
  change do
    add_column :apps, :service_binding_k8s_enabled, :boolean, default: false, null: false
  end
end
