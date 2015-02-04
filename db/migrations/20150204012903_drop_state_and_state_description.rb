Sequel.migration do
  up do
    alter_table :service_instances do
      drop_column :state
      drop_column :state_description
    end
  end

  down do
    alter_table :service_instances do
      add_column :service_instances, :state, String
      add_column :service_instances, :state_description, String, text: true
    end
  end
end
