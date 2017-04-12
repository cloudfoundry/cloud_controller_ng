require 'cloud_controller/backends/quota_validating_staging_memory_calculator'
require 'cloud_controller/backends/staging_disk_calculator'
require 'cloud_controller/backends/staging_environment_builder'
require 'cloud_controller/diego/staging_details'
require 'cloud_controller/diego/lifecycles/lifecycle_provider'
require 'repositories/droplet_event_repository'

module VCAP::CloudController
  class BuildCreate
    class BuildError < StandardError
    end
    class InvalidPackage < BuildError
    end
    class SpaceQuotaExceeded < BuildError
    end
    class OrgQuotaExceeded < BuildError
    end
    class DiskLimitExceeded < BuildError
    end

    attr_reader :staging_response

    def initialize(memory_limit_calculator: QuotaValidatingStagingMemoryCalculator.new,
      disk_limit_calculator: StagingDiskCalculator.new,
      environment_presenter: StagingEnvironmentBuilder.new)

      @memory_limit_calculator = memory_limit_calculator
      @disk_limit_calculator   = disk_limit_calculator
      @environment_builder     = environment_presenter
    end

    def create_and_stage(package:, lifecycle:, message:, start_after_staging: false)
      logger.info("creating build for package #{message.package_guid}")
      raise InvalidPackage.new('Cannot stage package whose state is not ready.') if package.state != PackageModel::READY_STATE

      staging_details                     = get_staging_details(package, lifecycle)
      staging_details.start_after_staging = start_after_staging

      build = BuildModel.new({
        state:        BuildModel::STAGING_STATE,
        package_guid: message.package_guid,
      }.merge(lifecycle.pre_known_receipt_information))

      BuildModel.db.transaction do
        build.save
        staging_details.staging_guid = build.guid
        lifecycle.create_lifecycle_data_model_for_build(build)
      end

      logger.info("build created: #{build.guid}")
      logger.info("staging package: #{package.inspect} for build #{build.guid}")
      @staging_response = stagers.stager_for_app(package.app).stage(staging_details)
      logger.info("package staging requested: #{package.inspect}")

      build
    end

    alias_method :create_and_stage_without_event, :create_and_stage

    private

    def get_staging_details(package, lifecycle)
      app   = package.app
      space = package.space
      org   = space.organization

      memory_limit          = get_memory_limit(lifecycle.staging_message.staging_memory_in_mb, space, org)
      disk_limit            = get_disk_limit(lifecycle.staging_message.staging_disk_in_mb)
      environment_variables = @environment_builder.build(app,
        space,
        lifecycle,
        memory_limit,
        disk_limit,
        lifecycle.staging_message.environment_variables)

      staging_details                       = Diego::StagingDetails.new
      staging_details.package               = package
      staging_details.staging_memory_in_mb  = memory_limit
      staging_details.staging_disk_in_mb    = disk_limit
      staging_details.environment_variables = environment_variables
      staging_details.lifecycle             = lifecycle
      staging_details.isolation_segment     = IsolationSegmentSelector.for_space(space)

      staging_details
    end

    def get_disk_limit(requested_limit)
      @disk_limit_calculator.get_limit(requested_limit)
    rescue StagingDiskCalculator::LimitExceeded
      raise DiskLimitExceeded
    end

    def get_memory_limit(requested_limit, space, org)
      @memory_limit_calculator.get_limit(requested_limit, space, org)
    rescue QuotaValidatingStagingMemoryCalculator::SpaceQuotaExceeded => e
      raise SpaceQuotaExceeded.new e.message
    rescue QuotaValidatingStagingMemoryCalculator::OrgQuotaExceeded => e
      raise OrgQuotaExceeded.new e.message
    end

    def logger
      @logger ||= Steno.logger('cc.action.build_create')
    end

    def stagers
      CloudController::DependencyLocator.instance.stagers
    end
  end
end
