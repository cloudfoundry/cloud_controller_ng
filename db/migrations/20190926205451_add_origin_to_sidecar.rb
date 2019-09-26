Sequel.migration do
  change do
    alter_table :sidecars do
      add_column :origin, String, size: 255, default: 'user', allow_null: false
    end
  end
end
