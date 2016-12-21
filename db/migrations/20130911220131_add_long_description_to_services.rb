Sequel.migration do
  change do
    alter_table(:services) do
      if Sequel::Model.db.database_type == :mssql
        add_column :long_description, String, size: :max
      else
        add_column :long_description, String, text: true
      end
    end
  end
end
