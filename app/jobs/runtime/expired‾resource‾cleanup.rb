module VCAP::CloudController
  module Jobs
    module Runtime
      class ExpiredResourceCleanup < VCAP::CloudController::Jobs::CCJob
        def perform
          logger.info('Deleting expired droplet and package models')
          deleted_expired_droplets.each(&:destroy)
          deleted_expired_packages.each(&:destroy)
        end

        def max_attempts
          1
        end

        private

        def deleted_expired_droplets
          DropletModel.where(
            state: DropletModel::EXPIRED_STATE,
            droplet_hash: nil,
            sha256_checksum: nil,
          )
        end

        def deleted_expired_packages
          PackageModel.where(
            state: PackageModel::EXPIRED_STATE,
            package_hash: nil,
            sha256_checksum: nil,
          )
        end

        def logger
          @logger ||= Steno.logger('cc.background')
        end
      end
    end
  end
end
