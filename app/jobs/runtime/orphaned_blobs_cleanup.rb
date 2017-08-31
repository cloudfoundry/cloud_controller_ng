require 'cloud_controller/dependency_locator'
require 'cloud_controller/clock/clock'
require 'repositories/orphaned_blob_event_repository'

module VCAP::CloudController
  module Jobs
    module Runtime
      class OrphanedBlobsCleanup < VCAP::CloudController::Jobs::CCJob
        DIRTY_THRESHOLD            = 3
        NUMBER_OF_BLOBS_TO_DELETE  = 10000
        IGNORED_DIRECTORY_PREFIXES = [
          CloudController::DependencyLocator::BUILDPACK_CACHE_DIR,
          CloudController::DependencyLocator::RESOURCE_POOL_DIR,
        ].freeze

        def perform
          unless config.get(:perform_blob_cleanup)
            logger.info('Skipping OrphanedBlobsCleanup as the `perform_blob_cleanup` manifest property is false')
            return
          end

          day_of_week = Time.now.wday
          cleanup(day_of_week)
        end

        def cleanup(day_of_week)
          logger.info("Started orphaned blobs cleanup job for day of week: #{day_of_week}")

          update_existing_orphaned_blobs

          number_of_marked_blobs = 0

          unique_blobstores.each do |blobstore_config|
            blobstore_type = blobstore_config[:type].to_s
            directory_key  = blobstore_config[:directory_key]
            blobstore      = CloudController::DependencyLocator.instance.public_send(blobstore_type)

            daily_directory_subset(day_of_week).each do |prefix|
              blobstore.files_for(prefix).each do |blob|
                next if blob_in_use?(blob.key) || OrphanedBlob.find(blob_key: blob.key, blobstore_type: blobstore_type)

                logger.info("Creating orphaned blob: #{blob.key} from directory_key: #{directory_key}")
                OrphanedBlob.create(blob_key: blob.key, dirty_count: 1, blobstore_type: blobstore_type)
                number_of_marked_blobs += 1

                if number_of_marked_blobs >= NUMBER_OF_BLOBS_TO_DELETE
                  logger.info("Finished orphaned blobs cleanup job early after marking #{number_of_marked_blobs} blobs")
                  return 'finished-early'
                end
              end
            end
          end
        rescue CloudController::Blobstore::BlobstoreError => e
          logger.error("Failed orphaned blobs cleanup job with BlobstoreError: #{e.message}")
          raise
        ensure
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

        def unique_blobstores
          return @unique_blobstores if @unique_blobstores.present?

          full_list = [
            {
              type:          :droplet_blobstore,
              directory_key: config.get(:droplets, :droplet_directory_key),
              root_dir:      CloudController::DependencyLocator.instance.public_send(:droplet_blobstore).root_dir
            },
            {
              type:          :package_blobstore,
              directory_key: config.get(:packages, :app_package_directory_key),
              root_dir:      CloudController::DependencyLocator.instance.public_send(:package_blobstore).root_dir
            },
            {
              type:          :buildpack_blobstore,
              directory_key: config.get(:buildpacks, :buildpack_directory_key),
              root_dir:      CloudController::DependencyLocator.instance.public_send(:buildpack_blobstore).root_dir
            },
            {
              type:          :legacy_global_app_bits_cache,
              directory_key: config.get(:resource_pool, :resource_directory_key),
              root_dir:      CloudController::DependencyLocator.instance.public_send(:legacy_global_app_bits_cache).root_dir
            },
          ]

          unique_blobstores = []
          full_list.each do |blobstore_config|
            unique_blobstores << blobstore_config unless unique_blobstores.any? do |b|
              b[:directory_key] == blobstore_config[:directory_key] && b[:root_dir] == blobstore_config[:root_dir]
            end
          end

          @unique_blobstores = unique_blobstores
        end

        def update_existing_orphaned_blobs
          dataset = OrphanedBlob.order(Sequel.desc(:dirty_count)).limit(NUMBER_OF_BLOBS_TO_DELETE)

          dataset.each do |orphaned_blob|
            if blob_in_use?(orphaned_blob.blob_key)
              unorphan_blob(orphaned_blob)
              next
            end

            logger.info("Incrementing dirty count for blob: #{orphaned_blob.blob_key}")
            orphaned_blob.update(dirty_count: Sequel.+(:dirty_count, 1))
          end
        end

        def unorphan_blob(orphaned_blob)
          logger.info("Un-orphaning previously orphaned blob: #{orphaned_blob.blob_key}")
          orphaned_blob.delete
        end

        def daily_directory_subset(day_of_week)
          # Our blobstore directories are namespaced using hex-values (e.g. 00/6c, ff/56, etc.)
          directory_subsets = [0x00..0x24, 0x25..0x48, 0x49..0x6c, 0x6d..0x90, 0x91..0xb4, 0xb5..0xd8, 0xd9..0xff].freeze

          directories_to_iterate = directory_subsets[day_of_week]
          directories_to_iterate.map { |decimal| decimal.to_s(16).rjust(2, '0') }
        end

        def blob_in_use?(blob_key)
          path_parts             = blob_key.split(File::Separator)
          potential_droplet_guid = path_parts[-2]
          basename               = path_parts[-1]

          blob_key.start_with?(*IGNORED_DIRECTORY_PREFIXES) ||
            DropletModel.find(guid: potential_droplet_guid, droplet_hash: basename).present? ||
            PackageModel.find(guid: basename).present? ||
            Buildpack.find(key: basename).present?
        end

        def delete_orphaned_blobs
          logger.info('Attempting to delete orphaned blobs')

          dataset = OrphanedBlob.where { dirty_count >= DIRTY_THRESHOLD }.
                    order(Sequel.desc(:dirty_count)).
                    limit(NUMBER_OF_BLOBS_TO_DELETE)

          dataset.each do |orphaned_blob|
            unpartitioned_blob_key = CloudController::Blobstore::BlobKeyGenerator.key_from_full_path(orphaned_blob.blob_key)
            blobstore_type         = orphaned_blob.blobstore_type.to_sym
            directory_key          = directory_key_for_type(blobstore_type)

            logger.info("Enqueuing deletion of orphaned blob #{orphaned_blob.blob_key} inside directory_key #{directory_key}")
            Jobs::Enqueuer.new(BlobstoreDelete.new(unpartitioned_blob_key, blobstore_type), queue: 'cc-generic', priority: VCAP::CloudController::Clock::LOW_PRIORITY).enqueue

            VCAP::CloudController::Repositories::OrphanedBlobEventRepository.record_delete(directory_key, orphaned_blob.blob_key)
            orphaned_blob.delete
          end
        end

        def directory_key_for_type(type)
          blobstore_config = unique_blobstores.find { |b| b[:type].to_s == type.to_s }
          if blobstore_config.nil?
            raise "Could not find blobstore config matching blobstore type '#{type}': #{unique_blobstores.inspect}"
          end
          blobstore_config[:directory_key]
        end

        def logger
          @logger ||= Steno.logger('cc.background.orphaned-blobs-cleanup')
        end

        def config
          @config ||= Config.config
        end
      end
    end
  end
end
