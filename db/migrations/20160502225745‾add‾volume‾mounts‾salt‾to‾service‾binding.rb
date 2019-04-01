Sequel.migration do
  change do
    alter_table :service_bindings do
      add_column :volume_mounts_salt, String
    end
  end
end
