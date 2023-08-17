Sequel.migration do
  change do
    alter_table :processes do
      add_column :readiness_health_check_http_endpoint, String, size: 2048
      add_column :readiness_health_check_invocation_timeout, :integer, null: true, default: nil
      add_column :readiness_health_check_type, String, size: 255, default: 'process'
    end
  end
end
