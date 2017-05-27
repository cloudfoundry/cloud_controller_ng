module VCAP::CloudController
  module Jobs
    module Runtime
      class OrphanedBlobsCleanup < VCAP::CloudController::Jobs::CCJob
        DIRTY_THRESHOLD = 3
        NUMBER_OF_BLOBS_TO_DELETE = 100

        def perform
          blobstores.each do |blobstore_name|
            blobstore = CloudController::DependencyLocator.instance.public_send(blobstore_name)
            blobstore.files.each do |blob|
              orphaned_blob = OrphanedBlob.find(blob_key: blob.key)
              if blob_in_use(blob)
                if orphaned_blob.present?
                  orphaned_blob.delete
                end

                next
              end

              create_or_update_orphaned_blob(blob, orphaned_blob, blobstore_name)
            end
          end

          delete_orphaned_blobs
        end

        def max_attempts
          1
        end

        private

        def blobstores
          config = Config.config

          result = {}

          result[config.dig(:droplets, :droplet_directory_key)]     = :droplet_blobstore
          result[config.dig(:packages, :app_package_directory_key)] = :package_blobstore
          result[config.dig(:buildpacks, :buildpack_directory_key)] = :buildpack_blobstore

          result.values
        end

        def logger
          @logger ||= Steno.logger('cc.background')
        end

        def blob_in_use(blob)
          parts = blob.key.split('/')
          basename = parts[-1]
          potential_droplet_guid = parts[-2]

          blob.key.start_with?(CloudController::DependencyLocator::BUILDPACK_CACHE_DIR, CloudController::DependencyLocator::RESOURCE_POOL_DIR) ||
            DropletModel.find(guid: potential_droplet_guid, droplet_hash: basename).present? ||
            PackageModel.find(guid: basename).present? ||
            Buildpack.find(key: basename).present?
        end

        def create_or_update_orphaned_blob(blob, orphaned_blob, blobstore)
          if orphaned_blob.present?
            orphaned_blob.update(dirty_count: Sequel.+(:dirty_count, 1))
          else
            OrphanedBlob.create(blob_key: blob.key, dirty_count: 1, blobstore_name: blobstore.to_s)
          end
        end

        def delete_orphaned_blobs
          dataset = OrphanedBlob.where { dirty_count >= DIRTY_THRESHOLD }.
                    order(Sequel.desc(:dirty_count)).
                    limit(NUMBER_OF_BLOBS_TO_DELETE)

          dataset.each do |orphaned_blob|
            unparitioned_blob_key = orphaned_blob.blob_key[6..-1]
            blobstore = orphaned_blob.blobstore_name
            Jobs::Enqueuer.new(BlobstoreDelete.new(unparitioned_blob_key, blobstore.to_sym), queue: 'cc-generic').enqueue
            orphaned_blob.delete
          end
        end
      end
    end
  end
end
