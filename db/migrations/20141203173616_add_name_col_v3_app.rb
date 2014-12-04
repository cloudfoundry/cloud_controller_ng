Sequel.migration do
  up do
    self[:apps_v3].truncate
    alter_table(:apps_v3) do
      add_column :name, String, null: false
      add_index :name
    end
  end

  down do
    alter_table(:apps_v3) do
      drop_index :name
      drop_column :name
    end
  end
end
