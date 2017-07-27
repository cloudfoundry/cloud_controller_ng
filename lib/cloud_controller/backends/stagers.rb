require 'cloud_controller/diego/stager'
require 'cloud_controller/diego/protocol'
require 'cloud_controller/diego/buildpack/staging_completion_handler'
require 'cloud_controller/diego/buildpack/lifecycle_protocol'
require 'cloud_controller/diego/docker/lifecycle_protocol'
require 'cloud_controller/diego/docker/staging_completion_handler'
require 'cloud_controller/diego/egress_rules'

module VCAP::CloudController
  class Stagers
    def initialize(config)
      @config = config
    end

    def validate_process(process)
      if process.docker? && FeatureFlag.disabled?(:diego_docker)
        raise CloudController::Errors::ApiError.new_from_details('DockerDisabled')
      end

      if process.package_hash.blank?
        raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid', 'The app package hash is empty')
      end

      if Buildpack.count == 0 && using_admin_buildpack?(process.app.lifecycle_data.buildpacks)
        raise CloudController::Errors::ApiError.new_from_details('NoBuildpacksFound')
      end
    end

    def stager_for_app
      Diego::Stager.new(@config)
    end

    private

    def using_admin_buildpack?(buildpacks)
      !buildpacks.all? { |buildpack_name| UriUtils.is_buildpack_uri?(buildpack_name) }
    end

    def dependency_locator
      CloudController::DependencyLocator.instance
    end
  end
end
