Sequel.migration do
  up do
    if Sequel::Model.db.database_type == :mssql
      set_column_type :service_instance_operations, :description, String, size: :max
    else
      set_column_type :service_instance_operations, :description, String, text: true
    end
  end

  down do
    set_column_type :service_instance_operations, :description, String
  end
end
