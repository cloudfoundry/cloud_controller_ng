require 'cloud_controller/dependency_locator'
require 'repositories/orphaned_blob_event_repository'

module VCAP::CloudController
  module Jobs
    module Runtime
      class OrphanedBlobsCleanup < VCAP::CloudController::Jobs::CCJob
        DIRTY_THRESHOLD            = 3
        NUMBER_OF_BLOBS_TO_DELETE  = 100
        IGNORED_DIRECTORY_PREFIXES = [
          CloudController::DependencyLocator::BUILDPACK_CACHE_DIR,
          CloudController::DependencyLocator::RESOURCE_POOL_DIR,
        ].freeze

        def perform
          logger.info('Started orphaned blobs cleanup job')

          number_of_marked_blobs = 0

          blobstores.each do |directory_key, blobstore_name|
            blobstore = CloudController::DependencyLocator.instance.public_send(blobstore_name)
            blobstore.files(IGNORED_DIRECTORY_PREFIXES).each do |blob|
              orphaned_blob = OrphanedBlob.find(blob_key: blob.key, directory_key: directory_key)
              next if skip_blob?(blob.key, orphaned_blob)

              create_or_update_orphaned_blob(blob, orphaned_blob, directory_key)

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

        def config
          @config ||= Config.config
        end

        def blobstores
          return @blobstores if @blobstores.present?

          result = {}

          result[config.dig(:droplets, :droplet_directory_key)]       = :droplet_blobstore
          result[config.dig(:packages, :app_package_directory_key)]   = :package_blobstore
          result[config.dig(:buildpacks, :buildpack_directory_key)]   = :buildpack_blobstore
          result[config.dig(:resource_pool, :resource_directory_key)] = :legacy_global_app_bits_cache

          @blobstores = result
        end

        def skip_blob?(blob_key, orphaned_blob)
          if blob_in_use(blob_key)
            if orphaned_blob.present?
              orphaned_blob.delete
            end

            return true
          end
          false
        end

        def blob_in_use(blob_key)
          path_parts = blob_key.split(File::Separator)
          potential_droplet_guid = path_parts[-2]
          basename = path_parts[-1]

          blob_key.start_with?(*IGNORED_DIRECTORY_PREFIXES) ||
            DropletModel.find(guid: potential_droplet_guid, droplet_hash: basename).present? ||
            PackageModel.find(guid: basename).present? ||
            Buildpack.find(key: basename).present?
        end

        def create_or_update_orphaned_blob(blob, orphaned_blob, directory_key)
          if orphaned_blob.present?
            logger.info("Incrementing dirty count for blob: #{orphaned_blob.blob_key}")
            orphaned_blob.update(dirty_count: Sequel.+(:dirty_count, 1))
          else
            logger.info("Creating orphaned blob: #{blob.key} from directory_key: #{directory_key}")
            OrphanedBlob.create(blob_key: blob.key, dirty_count: 1, directory_key: directory_key)
          end
        end

        def delete_orphaned_blobs
          dataset = OrphanedBlob.where { dirty_count >= DIRTY_THRESHOLD }.
                    order(Sequel.desc(:dirty_count)).
                    limit(NUMBER_OF_BLOBS_TO_DELETE)

          dataset.each do |orphaned_blob|
            unpartitioned_blob_key = CloudController::Blobstore::BlobKeyGenerator.key_from_full_path(orphaned_blob.blob_key)
            directory_key          = orphaned_blob.directory_key
            blobstore              = blobstores[directory_key]

            logger.info("Enqueuing deletion of orphaned blob #{orphaned_blob.blob_key} inside directory_key #{directory_key}")
            Jobs::Enqueuer.new(BlobstoreDelete.new(unpartitioned_blob_key, blobstore), queue: 'cc-generic').enqueue

            VCAP::CloudController::Repositories::OrphanedBlobEventRepository.record_delete(directory_key, orphaned_blob.blob_key)
            orphaned_blob.delete
          end
        end
      end
    end
  end
end
