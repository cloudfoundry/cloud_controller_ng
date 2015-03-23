Sequel.migration do
  up do
    set_column_type :service_instance_operations, :description, String, text: true
  end

  down do
    set_column_type :service_instance_operations, :description, String
  end
end
