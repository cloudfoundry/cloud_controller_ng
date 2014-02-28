module VCAP::CloudController
  class BuildpackBitsDelete
    def self.delete_when_safe(blobstore_key, blobstore_name, staging_timeout)
      return unless blobstore_key
      blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(blobstore_key, blobstore_name)
      Delayed::Job.enqueue(blobstore_delete, queue: "cc-generic", run_at: Delayed::Job.db_time_now + staging_timeout)
    end
  end
end
