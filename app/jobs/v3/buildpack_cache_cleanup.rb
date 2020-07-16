module VCAP::CloudController
  module Jobs
    module V3
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

        def display_name
          'admin.clear_buildpack_cache'
        end

        def max_attempts
          3
        end

        def resource_guid
          ''
        end

        def resource_type
          ''
        end
      end
    end
  end
end
