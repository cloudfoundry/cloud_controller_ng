Sequel.migration do
  up do
    alter_table :service_bindings do
      set_column_type :syslog_drain_url, String, text: true
    end
  end
end
