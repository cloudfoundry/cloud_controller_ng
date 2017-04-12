Sequel.migration do
  change do
    add_column :builds, :docker_receipt_image, String
  end
end
