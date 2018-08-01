module VCAP::CloudController
  module Jobs
    module Runtime
      class DeleteExpiredDropletBlob < VCAP::CloudController::Jobs::CCJob
        attr_reader :droplet_guid

        def initialize(droplet_guid)
          @droplet_guid = droplet_guid
        end

        def perform
          logger.info("Deleting expired droplet blob for droplet: #{droplet_guid}")

          droplet = DropletModel.find(guid: droplet_guid)
          return unless droplet
          BlobstoreDelete.new(droplet.blobstore_key, :droplet_blobstore).perform
          droplet.update(droplet_hash: nil, sha256_checksum: nil)
        end

        def job_name_in_configuration
          :delete_expired_droplet_blob
        end

        def max_attempts
          1
        end

        def logger
          @logger ||= Steno.logger('cc.background')
        end
      end
    end
  end
end
