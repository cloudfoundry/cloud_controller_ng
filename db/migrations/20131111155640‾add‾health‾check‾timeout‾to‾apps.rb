Sequel.migration do
  change do
    alter_table(:apps) do
      add_column :health_check_timeout, Integer
    end
  end
end
