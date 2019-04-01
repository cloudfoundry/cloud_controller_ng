Sequel.migration do
  up do
    alter_table :service_bindings do
      # rubocop:disable Migration/IncludeStringSize
      set_column_type :syslog_drain_url, String, text: true
      # rubocop:enable Migration/IncludeStringSize
    end
  end
end
