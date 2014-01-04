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
      case klass.name.demodulize
        when "CrashesController", "SpaceSummariesController"
          {health_manager_client: dependency_locator.health_manager_client}
        when "BuildpacksController", "BuildpackBitsController"
          {
            buildpack_blobstore: dependency_locator.buildpack_blobstore,
            upload_handler: dependency_locator.upload_handler
          }
        when "StagingsController"
          {
            droplet_blobstore: dependency_locator.droplet_blobstore,
            buildpack_cache_blobstore: dependency_locator.buildpack_cache_blobstore,
            package_blobstore: dependency_locator.package_blobstore,
            config: @config,
          }
        when "AppsController", "SpacesController"
          {
            event_repository: dependency_locator.event_repository
          }
        else
          {}
      end
    end
  end
end
