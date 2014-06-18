module VCAP::CloudController
  class BuildpackBitsDelete
    def self.delete_when_safe(blobstore_key, staging_timeout)
      return unless blobstore_key

      blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
      blob = blobstore.blob(blobstore_key)
      return unless blob

      attrs = blob.attributes(*CloudController::Blobstore::Blob::CACHE_ATTRIBUTES)
      blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(blobstore_key, :buildpack_blobstore, attrs)
      Delayed::Job.enqueue(blobstore_delete, queue: "cc-generic", run_at: Delayed::Job.db_time_now + staging_timeout)
    end
  end
end
