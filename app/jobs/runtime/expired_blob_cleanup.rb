module VCAP::CloudController
  module Jobs
    module Runtime
      class ExpiredBlobCleanup < VCAP::CloudController::Jobs::CCJob
        def perform
          logger.info('Deleting package and droplet blobs that are expired or failed')

          DropletModel.where(state: [DropletModel::EXPIRED_STATE, DropletModel::FAILED_STATE]).exclude(droplet_hash: nil).each do |droplet|
            enqueue_droplet_delete_job(droplet.guid)
          end

          PackageModel.where(state: PackageModel::EXPIRED_STATE).exclude(package_hash: nil).each do |package|
            enqueue_package_delete_job(package.guid)
          end
        end

        def job_name_in_configuration
          :expired_blob_cleanup
        end

        def max_attempts
          1
        end

        def enqueue_droplet_delete_job(droplet_guid)
          Jobs::Enqueuer.new(
            Jobs::Runtime::DeleteExpiredDropletBlob.new(droplet_guid),
            queue: 'cc-generic'
          ).enqueue
        end

        def enqueue_package_delete_job(package_guid)
          Jobs::Enqueuer.new(
            Jobs::Runtime::DeleteExpiredPackageBlob.new(package_guid),
            queue: 'cc-generic'
          ).enqueue
        end

        def logger
          @logger ||= Steno.logger('cc.background')
        end
      end
    end
  end
end
