Sequel.migration do
  change do
    alter_table :apps do
      set_column_type :encrypted_environment_variables, :text, limit: 16.megabytes - 1
    end
  end
end
