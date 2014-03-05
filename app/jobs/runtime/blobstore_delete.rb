module VCAP::CloudController
  module Jobs
    module Runtime
      class BlobstoreDelete < Struct.new(:key, :blobstore_name)
        def perform
          logger = Steno.logger("cc.background")
          logger.info("Deleting '#{key}' from blobstore '#{blobstore_name}'")
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

