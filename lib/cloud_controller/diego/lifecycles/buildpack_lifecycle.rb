require 'cloud_controller/diego/lifecycles/buildpack_info'
require 'cloud_controller/diego/lifecycles/buildpack_lifecycle_data_validator'
require 'queries/buildpack_lifecycle_fetcher'

module VCAP::CloudController
  class BuildpackLifecycle
    attr_reader :staging_message, :buildpack_info

    def initialize(package, staging_message)
      @staging_message = staging_message
      @package         = package

      db_result       = BuildpackLifecycleFetcher.new.fetch(buildpack_to_use, staging_stack)
      @buildpack_info = BuildpackInfo.new(buildpack_to_use, db_result[:buildpack])
      @validator      = BuildpackLifecycleDataValidator.new({ buildpack_info: buildpack_info, stack: db_result[:stack] })
    end

    delegate :valid?, :errors, to: :validator

    def type
      Lifecycles::BUILDPACK
    end

    def create_lifecycle_data_model(droplet)
      VCAP::CloudController::BuildpackLifecycleDataModel.create(
        buildpack: buildpack_to_use,
        stack:     requested_stack,
        droplet:   droplet
      )
    end

    def staging_environment_variables
      {
        'CF_STACK' => staging_stack
      }
    end

    def pre_known_receipt_information
      {
        buildpack_receipt_buildpack_guid: buildpack_info.buildpack_record.try(:guid),
        buildpack_receipt_stack_name:     staging_stack
      }
    end

    def staging_stack
      requested_stack || app_stack || VCAP::CloudController::Stack.default.name
    end

    private

    def buildpack_to_use
      if staging_message.buildpack_data.requested?(:buildpack)
        staging_message.buildpack_data.buildpack
      else
        @package.app.lifecycle_data.try(:buildpack)
      end
    end

    def requested_stack
      @staging_message.buildpack_data.stack
    end

    def app_stack
      @package.app.buildpack_lifecycle_data.try(:stack)
    end

    attr_reader :validator
  end
end
