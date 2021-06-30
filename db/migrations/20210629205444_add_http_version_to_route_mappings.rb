Sequel.migration do
  change do
    alter_table :route_mappings do
      add_column :http_version, :integer
    end
  end
end
