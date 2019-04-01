Sequel.migration do
  change do
    alter_table :app_security_groups do
      add_column :staging_default, TrueClass, default: false, required: true
      add_index :staging_default, name: 'asgs_staging_default'
    end
  end
end
