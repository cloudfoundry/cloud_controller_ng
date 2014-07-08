Sequel.migration do
  change do
    alter_table :apps do
      add_column :zone, String
    end
  end
end
