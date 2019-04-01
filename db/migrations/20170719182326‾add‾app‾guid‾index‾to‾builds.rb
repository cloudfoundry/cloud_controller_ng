Sequel.migration do
  change do
    alter_table :builds do
      add_index :app_guid, name: :builds_app_guid_index
    end
  end
end
