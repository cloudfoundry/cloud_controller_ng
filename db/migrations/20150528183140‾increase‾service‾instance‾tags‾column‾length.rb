Sequel.migration do
  up do
    alter_table :service_instances do
      set_column_type :tags, String, size: 1275, text: true
    end
  end

  down do
    alter_table :service_instances do
      set_column_type :tags, String
    end
  end
end
