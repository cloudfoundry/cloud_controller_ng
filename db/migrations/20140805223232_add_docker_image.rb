Sequel.migration do
  change do
    if Sequel::Model.db.database_type == :mssql
      add_column :apps, :docker_image, String, size: :max
    else
      add_column :apps, :docker_image, String, text: true
    end
  end
end
