Sequel.migration do
  change do
    alter_table :builds do
      add_foreign_key [:app_guid], :apps, key: :guid, name: :fk_builds_app_guid
    end
  end
end
