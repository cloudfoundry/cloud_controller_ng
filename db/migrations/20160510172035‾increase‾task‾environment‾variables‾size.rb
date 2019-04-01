Sequel.migration do
  up do
    alter_table :tasks do
      set_column_type :encrypted_environment_variables, String, text: true, null: true
    end
  end

  down do
    alter_table :tasks do
      set_column_type :encrypted_environment_variables, String, null: true
    end
  end
end
