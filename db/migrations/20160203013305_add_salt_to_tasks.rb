Sequel.migration do
  change do
    alter_table :tasks do
      rename_column :environment_variables, :encrypted_environment_variables
      add_column :salt, String
    end
  end
end
