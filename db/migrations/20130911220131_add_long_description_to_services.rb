Sequel.migration do
  change do
    alter_table(:services) do
      add_column :long_description, String, text: true
    end
  end
end
