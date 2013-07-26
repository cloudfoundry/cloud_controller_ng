Sequel.migration do
  change do
    alter_table(:apps) do
      add_column :salt, String
      add_column :encrypted_environment_json, String
    end
  end
end
