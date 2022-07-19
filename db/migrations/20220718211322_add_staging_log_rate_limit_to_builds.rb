Sequel.migration do
  change do
    alter_table :builds do
      add_column :staging_log_rate_limit, :Bignum, default: -1
    end
  end
end
