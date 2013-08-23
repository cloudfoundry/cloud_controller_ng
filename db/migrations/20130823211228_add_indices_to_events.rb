Sequel.migration do
  change do
    alter_table :events do
      add_index :timestamp
      add_index :type
    end
  end
end
