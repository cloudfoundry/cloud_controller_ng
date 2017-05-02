Sequel.migration do
  change do
    alter_table(:apps) do
      add_foreign_key [:space_guid], :spaces, key: :guid, name: :fk_apps_space_guid
    end
  end
end
