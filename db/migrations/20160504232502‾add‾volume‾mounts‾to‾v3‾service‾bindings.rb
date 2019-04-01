Sequel.migration do
  change do
    alter_table :v3_service_bindings do
      add_column :volume_mounts, String, text: true
      add_column :volume_mounts_salt, String
    end
  end
end
