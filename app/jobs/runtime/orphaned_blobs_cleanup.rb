require 'cloud_controller/dependency_locator'

module VCAP::CloudController
  module Jobs
    module Runtime
      class OrphanedBlobsCleanup < VCAP::CloudController::Jobs::CCJob
        DIRTY_THRESHOLD = 3
        NUMBER_OF_BLOBS_TO_DELETE = 100
        IGNORED_DIRECTORY_PREFIXES = [
          CloudController::DependencyLocator::BUILDPACK_CACHE_DIR,
          CloudController::DependencyLocator::RESOURCE_POOL_DIR,
        ].freeze

        def perform
          logger.info('Started orphaned blobs cleanup job')

          number_of_marked_blobs = 0

          blobstores.each do |blobstore_name|
            blobstore = CloudController::DependencyLocator.instance.public_send(blobstore_name)
            blobstore.files(IGNORED_DIRECTORY_PREFIXES).each do |blob|
              orphaned_blob = OrphanedBlob.find(blob_key: blob.key)
              next if skip_blob?(blob, orphaned_blob)

              create_or_update_orphaned_blob(blob, orphaned_blob, blobstore_name)

              number_of_marked_blobs += 1
              return 'finished-early' if number_of_marked_blobs >= NUMBER_OF_BLOBS_TO_DELETE
            end
          end
        ensure
          logger.info('Attempting to delete orphaned blobs')
          delete_orphaned_blobs
          logger.info('Finished orphaned blobs cleanup job')
        end

        def max_attempts
          1
        end

        def job_name_in_configuration
          :orphaned_blobs_cleanup
        end

        private

        def logger
          @logger ||= Steno.logger('cc.background.orphaned-blobs-cleanup')
        end

        def blobstores
          config = Config.config
          result = {}

          result[config.dig(:droplets, :droplet_directory_key)]     = :droplet_blobstore
          result[config.dig(:packages, :app_package_directory_key)] = :package_blobstore
          result[config.dig(:buildpacks, :buildpack_directory_key)] = :buildpack_blobstore

          result.values
        end

        def skip_blob?(blob, orphaned_blob)
          if blob_in_use(blob)
            if orphaned_blob.present?
              orphaned_blob.delete
            end

            return true
          end
          false
        end

        def blob_in_use(blob)
          parts = blob.key.split('/')
          basename = parts[-1]
          potential_droplet_guid = parts[-2]

          blob.key.start_with?(*IGNORED_DIRECTORY_PREFIXES) ||
            DropletModel.find(guid: potential_droplet_guid, droplet_hash: basename).present? ||
            PackageModel.find(guid: basename).present? ||
            Buildpack.find(key: basename).present?
        end

        def create_or_update_orphaned_blob(blob, orphaned_blob, blobstore)
          if orphaned_blob.present?
            logger.info("Incrementing dirty count for blob: #{orphaned_blob.blob_key}")
            orphaned_blob.update(dirty_count: Sequel.+(:dirty_count, 1))
          else
            logger.info("Creating orphaned blob: #{blob.key} in blobstore: #{blobstore}")
            OrphanedBlob.create(blob_key: blob.key, dirty_count: 1, blobstore_name: blobstore.to_s)
          end
        end

        def delete_orphaned_blobs
          dataset = OrphanedBlob.where { dirty_count >= DIRTY_THRESHOLD }.
                    order(Sequel.desc(:dirty_count)).
                    limit(NUMBER_OF_BLOBS_TO_DELETE)

          dataset.each do |orphaned_blob|
            unpartitioned_blob_key = orphaned_blob.blob_key[6..-1]
            blobstore = orphaned_blob.blobstore_name
            logger.info("Enqueuing deletion of orphaned blob #{orphaned_blob.blob_key}")
            Jobs::Enqueuer.new(BlobstoreDelete.new(unpartitioned_blob_key, blobstore.to_sym), queue: 'cc-generic').enqueue
            orphaned_blob.delete
          end
        end
      end
    end
  end
end
