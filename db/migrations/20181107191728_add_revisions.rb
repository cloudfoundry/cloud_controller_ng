Sequel.migration do
  change do
    create_table(:revisions) do
      VCAP::Migration.common(self)
      String :app_guid, size: 255
      foreign_key [:app_guid], :apps, key: :guid, name: :fk_revision_app_guid
      index [:app_guid], name: :fk_revision_app_guid_index
    end

    collate_opts = { size: 255 }
    if self.class.name.match?(/mysql/i)
      collate_opts[:collate] = :utf8_bin
    end

    alter_table(:processes) do
      # rubocop:disable Migration/IncludeStringSize
      add_column :revision_guid, String, collate_opts
      # rubocop:enable Migration/IncludeStringSize

      add_foreign_key [:revision_guid], :revisions, key: :guid, name: :fk_process_revision_guid
      add_index [:revision_guid], name: :fk_process_revision_guid_index
    end
  end
end
