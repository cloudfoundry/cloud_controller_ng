Sequel.migration do
  change do
    if Sequel::Model.db.database_type == :mssql
      add_column :apps, :package_pending_since, :datetime, null: true
    else
      add_column :apps, :package_pending_since, :timestamp, null: true
    end
    add_index :apps, :package_pending_since, name: 'apps_pkg_pending_since_index'
  end
end
