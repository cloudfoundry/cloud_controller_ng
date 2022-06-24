Sequel.migration do
  change do
    add_column :tasks, :log_quota, :Bignum, null: true, default: -1
  end
end
