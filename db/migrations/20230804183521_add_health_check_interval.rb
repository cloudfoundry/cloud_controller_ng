Sequel.migration do
  change do
    alter_table :processes do
      add_column :health_check_interval, :integer, null: true, default: nil
      add_column :readiness_health_check_interval, :integer, null: true, default: nil
    end
  end
end
