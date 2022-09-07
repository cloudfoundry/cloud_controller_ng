Sequel.migration do
  change do
    add_column :quota_definitions, :log_rate_limit, :Bignum, null: false, default: -1
    add_column :space_quota_definitions, :log_rate_limit, :Bignum, null: false, default: -1
    add_column :processes, :log_rate_limit, :Bignum, null: false, default: -1
    add_column :tasks, :log_rate_limit, :Bignum, null: false, default: -1
    add_column :builds, :staging_log_rate_limit, :Bignum, null: false, default: -1
  end
end
