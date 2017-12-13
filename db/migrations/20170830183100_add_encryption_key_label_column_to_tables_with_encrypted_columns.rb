Sequel.migration do
  up do
    tables_to_alter = %w(
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
    tables_to_alter.each do |table|
      alter_table(table.to_sym) do
        add_column :encryption_key_label, String, size: 255
      end
    end
  end

  down do
    if supports_table_listing?
      tables.each do |table|
        alter_table(table) do
          drop_column :encryption_key_label
        end
      end
    end
  end
end
