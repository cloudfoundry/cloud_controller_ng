module VCAP::CloudController
  module Jobs
    module Runtime
      class BlobstoreDelete < Struct.new(:key, :blobstore_name, :attributes)
        def perform
          logger = Steno.logger("cc.background")
          logger.info("Deleting '#{key}' from blobstore '#{blobstore_name}'")

          blobstore = CloudController::DependencyLocator.instance.public_send(blobstore_name)
          blob = blobstore.blob(key)
          if blob && same_blob(blob)
            blobstore.delete_blob(blob)
          end
        end

        def job_name_in_configuration
          :blobstore_delete
        end

        def max_attempts
          3
        end

        private

        def same_blob(blob)
          return true if attributes.nil?
          blob.attributes(*attributes.keys) == attributes
        end
      end
    end
  end
end
