Sequel.migration do
  change do
    alter_table(:revisions) do
      # Make sure column type matches `encrypted_environment_variables` on apps table
      # This is (necessarily) carrying forward mistakes of the past, see `include_string_size.rb`
      # for details on why text columns shouldn't be used in ccdb's database schema
      set_column_type(:encrypted_environment_variables, 'text')
    end
  end
end
