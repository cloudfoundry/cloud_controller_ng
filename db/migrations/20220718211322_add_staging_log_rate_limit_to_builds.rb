Sequel.migration do
  change do
    alter_table :builds do
      add_column :staging_log_rate_limit, :Bignum, null: false, default: -1
    end
  end
end
