Sequel.migration do
  change do
    if Sequel::Model.db.database_type == :mssql
      add_column :v3_droplets, :error, String, size: :max
    else
      add_column :v3_droplets, :error, String, text: true
    end
  end
end
