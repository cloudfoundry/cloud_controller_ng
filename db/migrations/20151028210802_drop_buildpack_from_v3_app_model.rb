Sequel.migration do
  up do
    drop_column :apps_v3, :buildpack
  end

  down do
    add_column :apps_v3, :buildpack, String, default: nil
  end
end
