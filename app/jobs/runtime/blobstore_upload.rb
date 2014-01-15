module VCAP::CloudController
  module Jobs
    module Runtime
      class BlobstoreUpload < Struct.new(:local_path, :blobstore_key, :blobstore_name)
        include VCAP::CloudController::TimedJob

        def perform
          begin
            Timeout.timeout max_run_time(:blobstore_upload) do
              blobstore = CloudController::DependencyLocator.instance.public_send(blobstore_name)
              blobstore.cp_to_blobstore(local_path, blobstore_key)
            end
          ensure
            FileUtils.rm_f(local_path)
          end
        end
      end
    end
  end
end
