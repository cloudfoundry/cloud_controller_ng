Sequel.migration do
  up do
    alter_table :services do
      if Sequel::Model.db.database_type == :mssql
        set_column_type :tags, String, size: :max
      else
        set_column_type :tags, String, text: true
      end
    end
  end

  down do
    alter_table :services do
      set_column_type :tags, 'varchar(255)'
    end
  end
end
