require 'cloud_controller/dea/stager'
require 'cloud_controller/diego/stager'
require 'cloud_controller/diego/protocol'
require 'cloud_controller/diego/buildpack/staging_completion_handler'
require 'cloud_controller/diego/buildpack/lifecycle_protocol'
require 'cloud_controller/diego/buildpack/v3/lifecycle_protocol'
require 'cloud_controller/diego/buildpack/v3/staging_completion_handler'
require 'cloud_controller/diego/docker/v3/lifecycle_protocol'
require 'cloud_controller/diego/docker/v3/staging_completion_handler'
require 'cloud_controller/diego/docker/lifecycle_protocol'
require 'cloud_controller/diego/docker/staging_completion_handler'
require 'cloud_controller/diego/egress_rules'
require 'cloud_controller/diego/v3/stager'
require 'cloud_controller/diego/v3/messenger'
require 'cloud_controller/diego/v3/protocol/app_protocol'

module VCAP::CloudController
  class Stagers
    def initialize(config, message_bus, dea_pool, runners)
      @config      = config
      @message_bus = message_bus
      @dea_pool    = dea_pool
      @runners     = runners
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

    def stager_for_package(package, lifecycle_type)
      protocol           = Diego::V3::Protocol::AppProtocol.new(diego_package_lifecycle_protocol(lifecycle_type), Diego::EgressRules.new)
      completion_handler = diego_package_completion_handler(lifecycle_type)
      Diego::V3::Stager.new(package, v3_messenger_for_protocol(protocol), completion_handler, @config)
    end

    def stager_for_app(app)
      app.diego? ? diego_stager(app) : dea_stager(app)
    end

    private

    def dea_stager(app)
      Dea::Stager.new(app, @config, @message_bus, @dea_pool, @runners)
    end

    def diego_stager(app)
      protocol           = Diego::Protocol.new(diego_lifecycle_protocol(app), Diego::EgressRules.new)
      completion_handler = diego_completion_handler(app)
      Diego::Stager.new(app, v2_messenger_for_protocol(protocol), completion_handler, @config)
    end

    def dependency_locator
      CloudController::DependencyLocator.instance
    end

    def v2_messenger_for_protocol(protocol)
      stager_client = dependency_locator.stager_client
      nsync_client  = dependency_locator.nsync_client
      Diego::Messenger.new(stager_client, nsync_client, protocol)
    end

    def v3_messenger_for_protocol(protocol)
      stager_client = dependency_locator.stager_client
      Diego::V3::Messenger.new(stager_client, protocol)
    end

    def diego_lifecycle_protocol(app)
      if app.docker_image.present?
        Diego::Docker::LifecycleProtocol.new
      else
        Diego::Buildpack::LifecycleProtocol.new(dependency_locator.blobstore_url_generator)
      end
    end

    def diego_package_lifecycle_protocol(lifecycle_type)
      if lifecycle_type == Lifecycles::BUILDPACK
        Diego::Buildpack::V3::LifecycleProtocol.new(dependency_locator.blobstore_url_generator)
      elsif lifecycle_type == Lifecycles::DOCKER
        Diego::Docker::V3::LifecycleProtocol.new
      end
    end

    def diego_completion_handler(app)
      if app.docker_image.present?
        Diego::Docker::StagingCompletionHandler.new(@runners)
      else
        Diego::Buildpack::StagingCompletionHandler.new(@runners)
      end
    end

    def diego_package_completion_handler(lifecycle_type)
      if lifecycle_type == Lifecycles::BUILDPACK
        Diego::Buildpack::V3::StagingCompletionHandler.new
      elsif lifecycle_type == Lifecycles::DOCKER
        Diego::Docker::V3::StagingCompletionHandler.new
      end
    end
  end
end
