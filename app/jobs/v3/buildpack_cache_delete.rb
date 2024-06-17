module VCAP::CloudController
  module Jobs
    module V3
      class BuildpackCacheDelete < VCAP::CloudController::Jobs::CCJob
        attr_accessor :resource_type, :resource_guid

        def initialize(app_guid)
          @resource_guid = app_guid
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info("Attempting delete of all blobs for app '#{resource_guid}' from blobstore buildpack_cache_blobstore")

          blobstore = CloudController::DependencyLocator.instance.public_send(:buildpack_cache_blobstore)
          blobstore.delete_all_in_path(resource_guid)
        end

        def job_name_in_configuration
          :buildpack_cache_delete
        end

        def max_attempts
          3
        end

        def display_name
          "#{resource_type}.clear_buildpack_cache"
        end
      end
    end
  end
end
