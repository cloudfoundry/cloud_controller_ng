Sequel.migration do
  change do
    alter_table :apps do
      add_column :ports, String, text: true
    end
  end
end
