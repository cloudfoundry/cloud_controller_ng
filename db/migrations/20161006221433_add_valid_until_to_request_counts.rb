Sequel.migration do
  change do
    alter_table :request_counts do
      add_column :valid_until, Time
    end
  end
end
