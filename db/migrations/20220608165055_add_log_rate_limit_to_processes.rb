Sequel.migration do
  change do
    add_column :processes, :log_rate_limit, :Bignum, null: false, default: -1
  end
end
