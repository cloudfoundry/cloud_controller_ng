Sequel.migration do
  change do
    add_column :apps, :package_pending_since, :timestamp, null: true
    add_index :apps, :package_pending_since, name: 'apps_pkg_pending_since_index'
  end
end
