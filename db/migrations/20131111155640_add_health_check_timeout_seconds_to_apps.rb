Sequel.migration do
  change do
    alter_table(:apps) do
      add_column :health_check_timeout_seconds, Integer
    end
  end
end
