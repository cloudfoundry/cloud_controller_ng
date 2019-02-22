Sequel.migration do
  change do
    create_table :revision_process_commands do
      VCAP::Migration.common(self)
      String :revision_guid, size: 255, null: false
      index :revision_guid, name: :rev_commands_revision_guid_index
      foreign_key [:revision_guid], :revisions, key: :guid, name: :rev_commands_revision_guid_fkey
      String :process_type, size: 255, null: false
      String :process_command, size: 4096
    end
  end
end
