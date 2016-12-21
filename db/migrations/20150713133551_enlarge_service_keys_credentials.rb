Sequel.migration do
  up do
    alter_table :service_keys do
      if Sequel::Model.db.database_type == :mssql
        set_column_type :credentials, String, null: false, size: :max
      else
        set_column_type :credentials, String, null: false, text: true
      end
    end
  end

  down do
    alter_table :service_keys do
      set_column_type :credentials, String, null: false, size: 2048
    end
  end
end
