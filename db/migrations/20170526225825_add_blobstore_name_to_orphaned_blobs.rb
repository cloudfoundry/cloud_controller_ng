Sequel.migration do
  change do
    add_column :orphaned_blobs, :blobstore_name, String
  end
end
