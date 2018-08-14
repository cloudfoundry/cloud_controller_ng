Sequel.migration do
  change do
    alter_table :route_mappings do
      add_column :weight, :integer, default: 1
    end
  end
end
