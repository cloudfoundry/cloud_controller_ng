Sequel.migration do
  change do
    alter_table(:revisions) do
      add_column :version, Integer, default: 1
    end

    alter_table(:deployments) do
      add_column :revision_version, Integer
    end
  end
end
