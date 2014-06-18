module VCAP::CloudController
  class BuildpackBitsDelete
    def self.delete_when_safe(blobstore_key, blobstore_name, staging_timeout)
      return unless blobstore_key

      b = blob(blobstore_key, blobstore_name)
      return unless b

      attrs = b.attributes(*CloudController::Blobstore::Blob::CACHE_ATTRIBUTES)
      blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(blobstore_key, blobstore_name, attrs)
      Delayed::Job.enqueue(blobstore_delete, queue: "cc-generic", run_at: Delayed::Job.db_time_now + staging_timeout)
    end

    private

    def self.blob(blobstore_key, blobstore_name)
      blobstore = CloudController::DependencyLocator.instance.public_send(blobstore_name)
      blobstore.blob(blobstore_key)
    end
  end
end
