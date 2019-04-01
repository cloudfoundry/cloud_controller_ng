Sequel.migration do
  tables_to_alter = %i(
    env_groups
    service_brokers
    service_bindings
    service_instances
    service_keys
    apps
    buildpack_lifecycle_buildpacks
    buildpack_lifecycle_data
    droplets
    packages
    tasks
  )
  up do
    tables_to_alter.each do |table|
      alter_table(table) do
        add_column :encryption_key_label, String, size: 255
      end
    end
  end

  down do
    tables_to_alter.each do |table|
      alter_table(table) do
        drop_column :encryption_key_label
      end
    end
  end
end
