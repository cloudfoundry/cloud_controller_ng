Sequel.migration do
  change do
    alter_table :apps do
      add_column :deleted_at, DateTime, null: true
    end
  end
end
