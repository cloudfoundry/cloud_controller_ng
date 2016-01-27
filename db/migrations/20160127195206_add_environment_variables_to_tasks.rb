Sequel.migration do
  change do
    alter_table :tasks do
      add_column :environment_variables, String, null: true
    end
  end
end
