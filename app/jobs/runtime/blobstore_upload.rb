module VCAP::CloudController
  module Jobs
    module Runtime
      class BlobstoreUpload
        attr_reader :local_path, :blobstore_key, :blobstore_name
        attr_reader :max_attempts

        def initialize(local_path, blobstore_key, blobstore_name)
          @local_path = local_path
          @blobstore_key = blobstore_key
          @blobstore_name = blobstore_name
          @max_attempts = 3
        end

        def perform
          logger = Steno.logger("cc.background")
          logger.info("Uploading '#{blobstore_key}' to blobstore '#{blobstore_name}'")
          blobstore = CloudController::DependencyLocator.instance.public_send(blobstore_name)
          blobstore.cp_to_blobstore(local_path, blobstore_key)
          FileUtils.rm_f(local_path)
        end

        def job_name_in_configuration
          :blobstore_upload
        end

        def error(job, _)
          if !File.exists?(local_path)
            @max_attempts = 1
          end

          if job.attempts >= max_attempts - 1
            FileUtils.rm_f(local_path)
          end
        end
      end
    end
  end
end
