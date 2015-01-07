Sequel.migration do
  change do
    alter_table :service_instances do
      set_column_type :credentials, String, text: true
    end

    alter_table :service_bindings do
      set_column_type :credentials, String, text: true
    end
  end
end
