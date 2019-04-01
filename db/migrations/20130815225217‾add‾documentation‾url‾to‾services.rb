Sequel.migration do
  change do
    alter_table(:services) do
      add_column :documentation_url, String
    end
  end
end
