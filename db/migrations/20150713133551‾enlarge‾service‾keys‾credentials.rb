Sequel.migration do
  up do
    alter_table :service_keys do
      set_column_type :credentials, String, null: false, text: true
    end
  end

  down do
    alter_table :service_keys do
      set_column_type :credentials, String, null: false, size: 2048
    end
  end
end
