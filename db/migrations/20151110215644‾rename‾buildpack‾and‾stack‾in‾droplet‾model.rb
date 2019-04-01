Sequel.migration do
  change do
    rename_column :v3_droplets, :stack_name, :buildpack_receipt_stack_name
    rename_column :v3_droplets, :buildpack, :buildpack_receipt_buildpack
    rename_column :v3_droplets, :buildpack_guid, :buildpack_receipt_buildpack_guid
  end
end
