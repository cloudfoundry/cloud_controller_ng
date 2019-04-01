Sequel.migration do
  change do
    alter_table :service_instances do
      add_column :syslog_drain_url, String
    end
  end
end
