Sequel.migration do
  change do
    add_column :orphaned_blobs, :directory_key, String
  end
end
