require "cloud_controller/dea/backend"
require "cloud_controller/diego/backend"
require "cloud_controller/diego/traditional/protocol"
require "cloud_controller/diego/docker/protocol"

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

      if app.docker_image.present? && app.buildpack.custom?
        raise Errors::ApiError.new_from_details("DiegoDockerBuildpackConflict")
      end
    end

    def find_one_to_stage(app)
      if app.stage_with_diego?
        if app.docker_image.present?
          diego_docker_backend(app)
        else
          diego_traditional_backend(app)
        end
      else
        dea_backend(app)
      end
    end

    def find_one_to_run(app)
      if app.run_with_diego?
        if app.docker_image.present?
          diego_docker_backend(app)
        else
          diego_traditional_backend(app)
        end
      else
        dea_backend(app)
      end
    end

    private

    def diego_docker_backend(app)
      protocol = Diego::Docker::Protocol.new
      messenger = Diego::Messenger.new(@config[:diego], @message_bus, protocol)
      Diego::Backend.new(app, messenger, protocol)
    end

    def diego_traditional_backend(app)
      dependency_locator = CloudController::DependencyLocator.instance
      protocol = Diego::Traditional::Protocol.new(dependency_locator.blobstore_url_generator)
      messenger = Diego::Messenger.new(@config[:diego], @message_bus, protocol)

      Diego::Backend.new(app, messenger, protocol)
    end

    def dea_backend(app)
      Dea::Backend.new(app, @config, @message_bus, @dea_pool, @stager_pool)
    end
  end
end
