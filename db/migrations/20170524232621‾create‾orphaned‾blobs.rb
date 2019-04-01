Sequel.migration do
  change do
    create_table :orphaned_blobs do
      VCAP::Migration.common(self)
      String :blob_key, unique: true
      Integer :dirty_count

      index :blob_key, name: :orphaned_blobs_blob_key_index, unique: true
    end
  end
end
