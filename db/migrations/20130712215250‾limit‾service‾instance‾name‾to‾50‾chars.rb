Sequel.migration do
  up do
    alter_table :service_instances do
      set_column_type :name, 'varchar(50)'
    end
  end

  down do
    alter_table :service_instances do
      set_column_type :name, String
    end
  end
end
