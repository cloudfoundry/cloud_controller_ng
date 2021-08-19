Sequel.migration do
  change do
    alter_table :route_mappings do
      add_column :protocol, String, size: 255
    end
  end
end
