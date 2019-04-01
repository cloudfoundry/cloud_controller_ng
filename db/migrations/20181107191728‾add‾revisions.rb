Sequel.migration do
  change do
    create_table(:revisions) do
      VCAP::Migration.common(self)
      String :app_guid, size: 255
      foreign_key [:app_guid], :apps, key: :guid, name: :fk_revision_app_guid
      index [:app_guid], name: :fk_revision_app_guid_index
    end

    alter_table(:processes) do
      add_column :revision_guid, String, size: 255, index: { name: :processes_revision_guid_index }
    end
  end
end
