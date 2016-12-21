Sequel.migration do
  change do
    alter_table :v3_service_bindings do
      if Sequel::Model.db.database_type == :mssql
        add_column :volume_mounts, String, size: :max
      else
        add_column :volume_mounts, String, text: true
      end
      add_column :volume_mounts_salt, String
    end
  end
end
