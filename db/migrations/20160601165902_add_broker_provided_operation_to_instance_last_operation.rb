Sequel.migration do
  change do
    alter_table :service_instance_operations do
      if Sequel::Model.db.database_type == :mssql
        add_column :broker_provided_operation, String, size: :max
      else
        add_column :broker_provided_operation, String, text: true
      end
    end
  end
end
