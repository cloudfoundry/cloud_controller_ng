Sequel.migration do
  change do
    drop_column :builds, :docker_receipt_image
    drop_column :builds, :buildpack_receipt_buildpack_guid
    drop_column :builds, :buildpack_receipt_stack_name
  end
end
