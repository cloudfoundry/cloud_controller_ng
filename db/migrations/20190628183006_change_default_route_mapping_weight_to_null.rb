Sequel.migration do
  change do
    drop_column :route_mappings, :weight
    add_column :route_mappings, :weight, Integer, default: nil
  end
end
