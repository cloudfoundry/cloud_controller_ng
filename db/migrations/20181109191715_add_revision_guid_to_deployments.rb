Sequel.migration do
  change do
    alter_table(:deployments) do
      add_column :revision_guid, String, size: 255, index: { name: :deployments_revision_guid_index }
    end
  end
end
