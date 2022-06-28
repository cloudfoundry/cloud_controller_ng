Sequel.migration do
  change do
    alter_table(:deployments) do
      add_column :revision_guid, String, size: 255
    end
  end
end
