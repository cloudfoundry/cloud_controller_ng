Sequel.migration do
  change do
    alter_table :app_security_groups do
      add_column :running_default, FalseClass, default: false, required: true
      add_index :running_default, name: 'asgs_running_default'
    end
  end
end
