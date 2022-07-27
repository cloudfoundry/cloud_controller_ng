Sequel.migration do
  up do
    alter_table :service_bindings do
      add_full_text_index :syslog_drain_url, name: :service_bindings_syslog_drain_url_index, unique: false
    end
  end

  down do
    alter_table :service_bindings do
      drop_index :syslog_drain_url, name: :service_bindings_syslog_drain_url_index
    end
  end
end
