Sequel.migration do
  change do
    add_column :v3_droplets, :error, String, text: true
  end
end
