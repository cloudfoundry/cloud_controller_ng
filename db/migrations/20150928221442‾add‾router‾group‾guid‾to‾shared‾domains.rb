Sequel.migration do
  change do
    add_column :domains, :router_group_guid, String, default: nil
  end
end
