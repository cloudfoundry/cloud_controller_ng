require "cloud_controller/dea/backend"
require "cloud_controller/diego/backend"

module VCAP::CloudController
  class Backends
    def initialize(config, message_bus, dea_pool, stager_pool)
      @config = config
      @message_bus = message_bus
      @dea_pool = dea_pool
      @stager_pool = stager_pool
    end

    def validate_app_for_staging(app)
      if app.docker_image.present? && !@config[:diego]
        raise Errors::ApiError.new_from_details("DiegoDisabled")
      end

      if app.package_hash.nil? || app.package_hash.empty?
        raise Errors::ApiError.new_from_details("AppPackageInvalid", "The app package hash is empty")
      end

      if app.buildpack.custom? && !app.custom_buildpacks_enabled?
        raise Errors::ApiError.new_from_details("CustomBuildpacksDisabled")
      end
    end

    def find_one_to_stage(app)
      app.stage_with_diego? ? diego_backend(app) : dea_backend(app)
    end

    def find_one_to_run(app)
      app.run_with_diego? ? diego_backend(app) : dea_backend(app)
    end

    private

    def diego_backend(app)
      dependency_locator = CloudController::DependencyLocator.instance
      Diego::Backend.new(app, dependency_locator.diego_messenger)
    end

    def dea_backend(app)
      Dea::Backend.new(app, @config, @message_bus, @dea_pool, @stager_pool)
    end
  end
end
