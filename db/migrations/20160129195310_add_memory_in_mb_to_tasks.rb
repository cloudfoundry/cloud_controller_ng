Sequel.migration do
  change do
    alter_table :tasks do
      add_column :memory_in_mb, Integer, null: true
    end
  end
end
