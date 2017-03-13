Sequel.migration do
  change do
    alter_table :apps do
      if Sequel::Model.db.database_type == :mssql
        add_column :ports, String, size: :max
      else
        add_column :ports, String, text: true
      end
    end
  end
end
