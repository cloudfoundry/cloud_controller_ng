Sequel.migration do
  change do
    if Sequel::Model.db.database_type == :mssql
      rename_column :v3_droplets, :stack_name, 'BUILDPACK_RECEIPT_STACK_NAME'
      rename_column :v3_droplets, :buildpack, 'BUILDPACK_RECEIPT_BUILDPACK'
      rename_column :v3_droplets, :buildpack_guid, 'BUILDPACK_RECEIPT_BUILDPACK_GUID'
    else
      rename_column :v3_droplets, :stack_name, :buildpack_receipt_stack_name
      rename_column :v3_droplets, :buildpack, :buildpack_receipt_buildpack
      rename_column :v3_droplets, :buildpack_guid, :buildpack_receipt_buildpack_guid
    end
  end
end
