module CloudController
  class ControllerFactory
    include VCAP::CloudController

    def initialize(config, logger, env, params, body, sinatra = nil)
      @config = config
      @logger = logger
      @env = env
      @params = params
      @body = body
      @sinatra = sinatra
    end

    def create_controller(klass)
      dependencies = dependencies_for_class(klass)
      klass.new(@config, @logger, @env, @params, @body, @sinatra, dependencies)
    end

    private

    def dependency_locator
      DependencyLocator.instance
    end

    def dependencies_for_class(klass)
      default_dependencies = {
        object_renderer: dependency_locator.object_renderer,
        collection_renderer: dependency_locator.paginated_collection_renderer,
      }

      custom_dependencies = case klass.name.demodulize
        when "CrashesController", "SpaceSummariesController"
          { health_manager_client: dependency_locator.health_manager_client }
        when "BuildpacksController", "BuildpackBitsController"
          {
            buildpack_blobstore: dependency_locator.buildpack_blobstore,
            upload_handler: dependency_locator.upload_handler,
          }
        when "StagingsController"
          {
            droplet_blobstore: dependency_locator.droplet_blobstore,
            buildpack_cache_blobstore: dependency_locator.buildpack_cache_blobstore,
            package_blobstore: dependency_locator.package_blobstore,
            missing_blob_handler: dependency_locator.missing_blob_handler,
            blob_sender: dependency_locator.blob_sender,
            config: @config,
          }
        when "AppsController"
          { app_event_repository: dependency_locator.app_event_repository }
        when "SpacesController"
          { space_event_repository: dependency_locator.space_event_repository }
        when "BillingEventsController"
          {
            object_renderer: nil, # no object rendering
            collection_renderer: dependency_locator.entity_only_paginated_collection_renderer,
          }
        when "AppBitsDownloadController"
          {
              blob_sender: dependency_locator.blob_sender,
              package_blobstore: dependency_locator.package_blobstore,
              missing_blob_handler: dependency_locator.missing_blob_handler,
          }
        else
          {}
      end

      default_dependencies.merge(custom_dependencies)
    end
  end
end
