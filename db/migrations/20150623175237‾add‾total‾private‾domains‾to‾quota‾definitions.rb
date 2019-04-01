Sequel.migration do
  change do
    add_column :quota_definitions, :total_private_domains, :integer, null: false, default: -1
  end
end
