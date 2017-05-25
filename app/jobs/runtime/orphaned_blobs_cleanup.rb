module VCAP::CloudController
  module Jobs
    module Runtime
      class OrphanedBlobsCleanup < VCAP::CloudController::Jobs::CCJob
        DIRTY_THRESHOLD = 3

        def perform
          blobstore.files.each do |blob|
            orphaned_blob = OrphanedBlob.find(blob_key: blob.key)
            if blob_in_use(blob)
              if orphaned_blob.present?
                orphaned_blob.delete
              end

              next
            end

            if orphaned_blob.present?
              update_or_delete(orphaned_blob)
            else
              OrphanedBlob.create(blob_key: blob.key, dirty_count: 1)
            end
          end
        end

        def max_attempts
          1
        end

        private

        def logger
          @logger ||= Steno.logger('cc.background')
        end

        def blobstore
          CloudController::DependencyLocator.instance.droplet_blobstore
        end

        def blob_in_use(blob)
          parts = blob.key.split('/')
          basename = parts[-1]
          potential_droplet_guid = parts[-2]

          blob.key.start_with?(CloudController::DependencyLocator::BUILDPACK_CACHE_DIR) ||
            DropletModel.find(guid: potential_droplet_guid, droplet_hash: basename).present? ||
            PackageModel.find(guid: basename).present? ||
            Buildpack.find(key: basename).present?
        end

        def update_or_delete(orphaned_blob)
          if orphaned_blob.dirty_count == DIRTY_THRESHOLD
            blob_key = orphaned_blob.blob_key[6..-1]
            Jobs::Enqueuer.new(BlobstoreDelete.new(blob_key, :droplet_blobstore), queue: 'cc-generic').enqueue
            orphaned_blob.delete
          else
            orphaned_blob.update(dirty_count: Sequel.+(:dirty_count, 1))
          end
        end
      end
    end
  end
end
