Sequel.migration do
  change do
    alter_table :tasks do
      add_index :app_guid, name: :tasks_app_guid_index
    end
  end
end
