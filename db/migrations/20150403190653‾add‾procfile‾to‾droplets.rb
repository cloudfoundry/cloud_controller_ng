Sequel.migration do
  change do
    add_column :v3_droplets, :procfile, String, text: true
  end
end
