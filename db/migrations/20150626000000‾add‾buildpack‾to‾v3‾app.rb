Sequel.migration do
  change do
    add_column :apps_v3, :buildpack, String, default: nil
  end
end
