Sequel.migration do
  change do
    alter_table :droplets do
      add_column :sidecars, String, text: true, default: nil
    end
  end
end
