Sequel.migration do
  up do
    alter_table :quota_definitions do
      drop_column :trial_db_allowed
    end
  end

  down do
    alter_table :quota_definitions do
      add_column :trial_db_allowed, TrueClass, :default => false
    end
  end
end
