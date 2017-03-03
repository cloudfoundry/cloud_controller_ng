Sequel.migration do
  change do
    alter_table :packages do
      add_index :app_guid, name: :package_app_guid_index
    end
  end
end
