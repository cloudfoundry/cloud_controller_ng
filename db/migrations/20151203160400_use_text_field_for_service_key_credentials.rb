Sequel.migration do
  up do
    alter_table :service_key do
      set_column_type :credentials, String, text: true
    end
  end

  down do
    alter_table :service_key do
      set_column_type :credentials, String, size: 2048
    end
  end
end
