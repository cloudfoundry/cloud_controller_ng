Sequel.migration do
  change do
    alter_table :v3_droplets do
      add_column :encrypted_environment_variables, String, text: true
      add_column :salt, String
    end
  end
end
