module VCAP::CloudController
  module Jobs
    module Runtime
      class ExpiredResourceCleanup < VCAP::CloudController::Jobs::CCJob
        def perform
          logger.info('Deleting expired droplet models')
          deleted_expired_droplets.each(&:destroy)
        end

        def max_attempts
          1
        end

        private

        def deleted_expired_droplets
          DropletModel.where(
            state: DropletModel::EXPIRED_STATE,
            droplet_hash: nil
          )
        end

        def logger
          @logger ||= Steno.logger('cc.background')
        end
      end
    end
  end
end
