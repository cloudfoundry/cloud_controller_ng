Sequel.migration do
  change do
    if Sequel::Model.db.database_type == :mssql
      add_column :v3_droplets, :procfile, String, size: :max
    else
      add_column :v3_droplets, :procfile, String, text: true
    end
  end
end
