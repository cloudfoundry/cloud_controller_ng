Sequel.migration do
  change do
    alter_table(:revisions) do
      add_column :encrypted_environment_variables, String, size: 16_000
      add_column :salt, String, size: 255
      add_column :encryption_key_label, String, size: 255
    end
  end
end
