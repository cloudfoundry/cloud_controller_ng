module VCAP::CloudController
  module Jobs
    module V3
      class BuildpackCacheDelete < VCAP::CloudController::Jobs::CCJob
        attr_accessor :app_guid, :resource_guid, :resource_type, :model_class

        def initialize(model_class, app_guid, resource_type=nil)
          @model_class = model_class
          @app_guid = app_guid
          @resource_type = resource_type || model_class.name.demodulize.gsub('Model', '').underscore
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info("Attempting delete of all blobs for app '#{app_guid}' from blobstore buildpack_cache_blobstore")

          blobstore = CloudController::DependencyLocator.instance.public_send(:buildpack_cache_blobstore)
          blobstore.delete_all_in_path(app_guid)
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
