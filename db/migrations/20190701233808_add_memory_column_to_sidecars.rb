Sequel.migration do
  change do
    alter_table :sidecars do
      add_column :memory, Integer, default: nil
    end
  end
end
