Sequel.migration do
  change do
    alter_table(:stacks) do
      add_column :deprecated_at, DateTime, null: true
      add_column :locked_at, DateTime, null: true
      add_column :disabled_at, DateTime, null: true
    end
  end
end
