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
      if Sequel::Model.db.database_type == :mssql
        add_column :service_instances, :state_description, String, size: :max
      else
        add_column :service_instances, :state_description, String, text: true
      end
    end
  end
end
