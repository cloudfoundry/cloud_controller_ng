Sequel.migration do
  change do
    alter_table :service_bindings do
      add_column :syslog_drain_url, String
    end
  end
end
