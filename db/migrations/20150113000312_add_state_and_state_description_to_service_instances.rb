Sequel.migration do
  change do
    add_column :service_instances, :state, String
    if Sequel::Model.db.database_type == :mssql
      add_column :service_instances, :state_description, String, size: :max
    else
      add_column :service_instances, :state_description, String, text: true
    end
  end
end
