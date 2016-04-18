module VCAP::CloudController
  module Jobs
    module V3
      class DropletBitsCopier < VCAP::CloudController::Jobs::CCJob
        def initialize(src_droplet_guid, dest_droplet_guid)
          @src_droplet_guid  = src_droplet_guid
          @dest_droplet_guid = dest_droplet_guid
        end

        def perform
          logger.info("Copying the droplet bits from droplet '#{@src_droplet_guid}' to droplet '#{@dest_droplet_guid}'")
          raise 'destination droplet does not exist' unless destination_droplet
          copy_bits
        end

        def job_name_in_configuration
          :droplet_bits_copier
        end

        def max_attempts
          1
        end

        private

        def copy_bits
          source_droplet = DropletModel.find(guid: @src_droplet_guid)
          raise 'source droplet does not exist' unless source_droplet

          CloudController::DependencyLocator.instance.droplet_blobstore.
            cp_file_between_keys(source_droplet.blobstore_key, destination_droplet.blobstore_key(source_droplet.droplet_hash))

          destination_droplet.db.transaction do
            destination_droplet.lock!
            destination_droplet.droplet_hash = source_droplet.droplet_hash
            destination_droplet.state = source_droplet.state
            destination_droplet.save
          end
        rescue => e
          destination_droplet.db.transaction do
            destination_droplet.lock!
            destination_droplet.error = "failed to copy - #{e.message}"
            destination_droplet.state = DropletModel::FAILED_STATE
            destination_droplet.save
          end
          raise
        end

        def logger
          @logger ||= Steno.logger('cc.background')
        end

        def destination_droplet
          @destination_droplet ||= DropletModel.find(guid: @dest_droplet_guid)
        end
      end
    end
  end
end
