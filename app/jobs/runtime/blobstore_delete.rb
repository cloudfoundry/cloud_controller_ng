module VCAP::CloudController
  module Jobs
    module Runtime
      class BlobstoreDelete < Struct.new(:key, :blobstore_name)
        def perform
          blobstore = CloudController::DependencyLocator.instance.public_send(blobstore_name)
          blobstore.delete(key)
        end

        def job_name_in_configuration
          :blobstore_delete
        end
      end
    end
  end
end

