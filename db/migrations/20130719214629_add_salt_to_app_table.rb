Sequel.migration do
  change do
    alter_table(:apps) do
      add_column :salt, String
    end
  end
end
