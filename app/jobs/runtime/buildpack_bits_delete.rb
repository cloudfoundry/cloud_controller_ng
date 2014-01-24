module VCAP::CloudController
  module Jobs
    module Runtime
      class BuildpackBitsDelete
        def self.delete_buildpack_in_blobstore(blobstore_key, blobstore_name, config)
          return unless blobstore_key
          blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(blobstore_key, blobstore_name)
          Delayed::Job.enqueue(blobstore_delete, queue: "cc-generic", run_at: Delayed::Job.db_time_now + staging_timeout(config))
        end

        def self.staging_timeout(config)
          config[:staging] && config[:staging][:max_staging_runtime] || 120
        end

      end
    end
  end
end
