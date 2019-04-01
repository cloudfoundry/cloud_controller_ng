Sequel.migration do
  change do
    add_column :v3_droplets, :docker_receipt_image, String, default: nil
  end
end
