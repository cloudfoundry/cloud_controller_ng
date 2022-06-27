Sequel.migration do
  change do
    add_column :tasks, :log_rate_limit, :Bignum, null: true, default: -1
  end
end
