module VCAP::CloudController
  module Jobs
    module Runtime
      class BlobstoreDelete < Struct.new(:key, :blobstore_name)
        include VCAP::CloudController::TimedJob

        def perform
          Timeout.timeout max_run_time(:blobstore_delete) do
            blobstore = CloudController::DependencyLocator.instance.public_send(blobstore_name)
            blobstore.delete(key)
          end
        end
      end
    end
  end
end

