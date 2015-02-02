Sequel.migration do
  up do
    alter_table :service_instances do
      set_column_type :name, String
    end
  end

  down do
    alter_table :service_instances do
      set_column_type :name, String, size: 4095
    end
  end
end
