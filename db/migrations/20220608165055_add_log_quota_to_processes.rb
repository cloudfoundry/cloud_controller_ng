Sequel.migration do
  change do
    add_column :processes, :log_quota, :Bignum, null: true, default: -1
  end
end
