Sequel.migration do
  change do
    alter_table(:services) do
      add_column :tags, String
    end
  end
end
