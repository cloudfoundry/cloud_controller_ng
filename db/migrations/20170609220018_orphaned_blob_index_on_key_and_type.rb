Sequel.migration do
  change do
    # blob_key unique constraint was added without a name, so mysql and postgres will name them differently
    if self.class.name =~ /mysql/i
      alter_table :orphaned_blobs do
        drop_index :blob_key, name: :blob_key, type: :unique
      end
    elsif self.class.name =~ /postgres/i
      alter_table :orphaned_blobs do
        drop_constraint :blob_key, name: :orphaned_blobs_blob_key_key, type: :unique
      end
    end

    alter_table :orphaned_blobs do
      drop_index :blob_key, name: :orphaned_blobs_blob_key_index, type: :unique
      drop_column :directory_key
      add_column :blobstore_type, String
      add_index [:blob_key, :blobstore_type], name: :orphaned_blobs_unique_blob_index, unique: true
    end
  end
end
