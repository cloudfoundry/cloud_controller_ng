Sequel.migration do
  change do
    alter_table :apps_v3 do
      add_column :encrypted_environment_variables, String, text: true
      add_column :salt, String
    end
  end
end
