Sequel.migration do
  change do
    alter_table(:services) do
      add_column :requires, String
    end
  end
end
