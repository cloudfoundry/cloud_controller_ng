require 'cloud_controller/dea/stager'
require 'cloud_controller/diego/stager'
require 'cloud_controller/diego/traditional/protocol'
require 'cloud_controller/diego/traditional/staging_completion_handler'
require 'cloud_controller/diego/docker/protocol'
require 'cloud_controller/diego/docker/staging_completion_handler'
require 'cloud_controller/diego/egress_rules'
require 'cloud_controller/diego/v3/stager'
require 'cloud_controller/diego/v3/messenger'
require 'cloud_controller/diego/traditional/v3/staging_completion_handler'
require 'cloud_controller/diego/traditional/v3/protocol'

module VCAP::CloudController
  class Stagers
    def initialize(config, message_bus, dea_pool, stager_pool, runners)
      @config = config
      @message_bus = message_bus
      @dea_pool = dea_pool
      @stager_pool = stager_pool
      @runners = runners
    end

    def validate_app(app)
      if app.docker_image.present? && FeatureFlag.disabled?('diego_docker')
        raise Errors::ApiError.new_from_details('DockerDisabled')
      end

      if app.package_hash.blank?
        raise Errors::ApiError.new_from_details('AppPackageInvalid', 'The app package hash is empty')
      end

      if app.buildpack.custom? && !app.custom_buildpacks_enabled?
        raise Errors::ApiError.new_from_details('CustomBuildpacksDisabled')
      end

      if Buildpack.count == 0 && app.buildpack.custom? == false
        raise Errors::ApiError.new_from_details('NoBuildpacksFound')
      end
    end

    def stager_for_package(package)
      diego_package_stager(package)
    end

    def stager_for_app(app)
      app.diego? ? diego_stager(app) : dea_stager(app)
    end

    private

    def dea_stager(app)
      Dea::Stager.new(app, @config, @message_bus, @dea_pool, @stager_pool, @runners)
    end

    def diego_stager(app)
      app.docker_image.present? ? diego_docker_stager(app) : diego_traditional_stager(app)
    end

    def diego_docker_stager(app)
      dependency_locator = CloudController::DependencyLocator.instance
      stager_client = dependency_locator.stager_client
      protocol = Diego::Docker::Protocol.new(Diego::EgressRules.new)
      messenger = Diego::Messenger.new(stager_client, @message_bus, protocol)
      completion_handler = Diego::Docker::StagingCompletionHandler.new(@runners)
      Diego::Stager.new(app, messenger, completion_handler, @config)
    end

    def diego_traditional_stager(app)
      dependency_locator = CloudController::DependencyLocator.instance
      protocol = Diego::Traditional::Protocol.new(dependency_locator.blobstore_url_generator(true), Diego::EgressRules.new)
      stager_client = dependency_locator.stager_client
      messenger = Diego::Messenger.new(stager_client, @message_bus, protocol)
      completion_handler = Diego::Traditional::StagingCompletionHandler.new(@runners)
      Diego::Stager.new(app, messenger, completion_handler, @config)
    end

    def diego_package_stager(package)
      dependency_locator = CloudController::DependencyLocator.instance
      protocol = Diego::Traditional::V3::Protocol.new(dependency_locator.blobstore_url_generator(true), Diego::EgressRules.new)
      stager_client = dependency_locator.stager_client
      messenger = Diego::V3::Messenger.new(stager_client, @message_bus, protocol)
      completion_handler = Diego::Traditional::V3::StagingCompletionHandler.new(@runners)
      Diego::V3::Stager.new(package, messenger, completion_handler, @config)
    end
  end
end
