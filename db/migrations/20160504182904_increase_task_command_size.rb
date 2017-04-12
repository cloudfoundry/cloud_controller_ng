Sequel.migration do
  up do
    alter_table :tasks do
      if Sequel::Model.db.database_type == :mssql
        set_column_type :command, String, size: :max
      else
        set_column_type :command, String, text: true
      end
    end
  end

  down do
    alter_table :tasks do
      set_column_type :command, String
    end
  end
end
