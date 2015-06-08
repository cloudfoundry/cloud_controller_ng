module VCAP::CloudController
  module Jobs
    module Runtime
      class BuildpackCacheCleanup < VCAP::CloudController::Jobs::CCJob
        def perform
          logger = Steno.logger('cc.background')
          logger.info('Attempting cleanup of buildpack_cache blobstore')

          blobstore = CloudController::DependencyLocator.instance.buildpack_cache_blobstore
          blobstore.delete_all
        end

        def job_name_in_configuration
          :buildpack_cache_cleanup
        end

        def max_attempts
          3
        end
      end
    end
  end
end
