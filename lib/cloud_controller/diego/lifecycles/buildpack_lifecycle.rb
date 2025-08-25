require 'cloud_controller/diego/lifecycles/buildpack_info'
require 'cloud_controller/diego/lifecycles/lifecycle_base'
require 'cloud_controller/diego/lifecycles/buildpack_lifecycle_data_validator'
require 'fetchers/buildpack_lifecycle_fetcher'

module VCAP::CloudController
  class BuildpackLifecycle < LifecycleBase
    def type
      Lifecycles::BUILDPACK
    end

    def create_lifecycle_data_model(build)
      VCAP::CloudController::BuildpackLifecycleDataModel.create(
        buildpacks: Array(buildpacks_to_use),
        stack: staging_stack,
        build: build
      )
    end

    def staging_environment_variables
      {
        'CF_STACK' => normalize_stack_name_for_buildpack(staging_stack)
      }
    end

    def skip_detect?
      !buildpack_infos.empty?
    end

    private

    def app_stack
      @package.app.buildpack_lifecycle_data.try(:stack)
    end

    def normalize_stack_name_for_buildpack(stack_name)
      return stack_name unless stack_name.is_a?(String) && is_custom_stack?(stack_name)

      # Extract the image name from the Docker URL for buildpack compatibility
      # Examples:
      # https://docker.io/cloudfoundry/cflinuxfs4 -> cflinuxfs4
      # docker://cloudfoundry/cflinuxfs3 -> cflinuxfs3
      # docker.io/cloudfoundry/cflinuxfs4 -> cflinuxfs4
      normalized_url = stack_name.gsub(%r{^(https?://|docker://)}, '')
      if normalized_url.include?('/')
        # Extract the last part of the path
        parts = normalized_url.split('/')
        parts.last
      else
        # If no path, use as-is
        normalized_url
      end
    end

    def is_custom_stack?(stack_name)
      # Check for various container registry URL formats
      return true if stack_name.include?('docker://')
      return true if stack_name.match?(%r{^https?://})  # Any https/http URL
      return true if stack_name.include?('.')  # Any string with a dot (likely a registry)
      false
    end
  end
end
