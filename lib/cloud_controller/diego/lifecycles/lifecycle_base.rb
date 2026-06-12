require 'cloud_controller/diego/lifecycles/buildpack_info'
require 'fetchers/buildpack_lifecycle_fetcher'

module VCAP::CloudController
  class LifecycleBase
    attr_reader :staging_message, :buildpack_infos, :credentials_for_staging

    def initialize(package, staging_message)
      @staging_message = staging_message
      @package = package

      db_result = BuildpackLifecycleFetcher.fetch(buildpacks_to_use, staging_stack, type)
      @buildpack_infos = db_result[:buildpack_infos]

      stored = @package.app.lifecycle_data&.then { |ld| ld.respond_to?(:credentials) ? ld.credentials : nil }
      @credentials_for_staging = staging_message.buildpack_data.requested?(:credentials) ? staging_message.buildpack_data.credentials : stored

      @validator = validator_class.new(
        buildpack_infos: @buildpack_infos,
        stack: db_result[:stack],
        stack_name: staging_stack,
        credentials: @credentials_for_staging,
        credentials_from_message: staging_message.buildpack_data.requested?(:credentials)
      )
    end

    delegate :valid?, :errors, to: :validator

    def staging_stack
      @staging_stack ||= begin
        stack = requested_stack || app_stack || VCAP::CloudController::Stack.default.name
        FeatureFlag.raise_unless_enabled!(:diego_custom_stacks) if UriUtils.is_custom_stack_uri?(stack)
        stack
      end
    end

    private

    def validator_class
      BuildpackLifecycleDataValidator
    end

    def buildpacks_to_use
      staging_message.buildpack_data.buildpacks || @package.app.lifecycle_data.buildpacks
    end

    def requested_stack
      @staging_message.buildpack_data.stack
    end

    attr_reader :validator
  end
end
