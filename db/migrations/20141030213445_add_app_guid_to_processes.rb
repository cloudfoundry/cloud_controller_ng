Sequel.migration do
  change do
    alter_table(:apps) do
      add_column :app_guid, String
    end
  end
end
