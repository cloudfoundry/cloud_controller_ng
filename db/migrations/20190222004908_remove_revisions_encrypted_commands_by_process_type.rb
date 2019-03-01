Sequel.migration do
  change do
    alter_table(:revisions) do
      drop_column :encrypted_commands_by_process_type
    end
  end
end
