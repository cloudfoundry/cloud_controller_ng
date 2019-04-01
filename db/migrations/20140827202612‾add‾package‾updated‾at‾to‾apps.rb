Sequel.migration do
  change do
    add_column :apps, :package_updated_at, Time, default: nil
  end
end
