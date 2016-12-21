Sequel.migration do
  up do
    alter_table :service_instances do
      if Sequel::Model.db.database_type == :mssql
        set_column_type :tags, String, size: :max
      else
        set_column_type :tags, String, text: true
      end
    end
  end

  down do
    alter_table :service_instances do
      set_column_type :tags, String, size: 1275, text: true
    end
  end
end
