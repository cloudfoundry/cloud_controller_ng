Sequel.migration do
  change do
    add_column :quota_definitions, :log_rate_limit, :Bignum, null: false, default: -1
  end
end
