require 'cloud_controller/backends/quota_validating_staging_memory_calculator'
require 'cloud_controller/backends/staging_disk_calculator'
require 'cloud_controller/backends/staging_environment_builder'
require 'cloud_controller/diego/staging_details'
require 'cloud_controller/diego/lifecycles/lifecycle_provider'
require 'repositories/droplet_event_repository'

module VCAP::CloudController
  class BuildCreate
    class BuildError < StandardError; end
    class InvalidPackage < BuildError; end
    class SpaceQuotaExceeded < BuildError; end
    class OrgQuotaExceeded < BuildError; end
    class DiskLimitExceeded < BuildError; end

    attr_reader :staging_response

    def initialize(memory_limit_calculator: QuotaValidatingStagingMemoryCalculator.new,
      disk_limit_calculator: StagingDiskCalculator.new,
      environment_presenter: StagingEnvironmentBuilder.new)

      @memory_limit_calculator = memory_limit_calculator
      @disk_limit_calculator = disk_limit_calculator
      @environment_builder = environment_presenter
    end

    def create_and_stage(package:, lifecycle:, message:, user_audit_info:, start_after_staging: false, record_event: true)
      logger.info("creating build for package #{message.package_guid}")
      raise InvalidPackage.new('Cannot stage package whose state is not ready.') if package.state != PackageModel::READY_STATE

      staging_details = nil
      build = nil
      droplet = nil

      BuildModel.db.transaction do
        build = BuildModel.create(
          state: BuildModel::STAGING_STATE,
          package_guid: message.package_guid,
        )
        logger.info("build created: #{build.guid}")
        logger.info("staging package: #{package.inspect} with build #{build.guid}")

        staging_details = get_staging_details(package, lifecycle)
        staging_details.start_after_staging = start_after_staging

        droplet = DropletModel.create({
          app_guid: package.app.guid,
          package_guid: package.guid,
          state: DropletModel::STAGING_STATE,
          environment_variables: staging_details.environment_variables,
          staging_memory_in_mb: staging_details.staging_memory_in_mb,
          staging_disk_in_mb: staging_details.staging_disk_in_mb,
          build: build
        }.merge(lifecycle.pre_known_receipt_information))
        staging_details.staging_guid = droplet.guid

        lifecycle.create_lifecycle_data_model(droplet)
        record_audit_event(droplet, message, package, user_audit_info) if record_event

        logger.info("build / droplet created: #{build.guid} / #{droplet.guid}")
      end

      logger.info("staging package: #{package.inspect} for droplet #{droplet.guid}")
      @staging_response = stagers.stager_for_app(package.app).stage(staging_details)
      logger.info("package staging requested: #{package.inspect}")

      build
    end

    def create_and_stage_without_event(package:, lifecycle:, message:, start_after_staging: false)
      create_and_stage(package: package,
                       lifecycle: lifecycle,
                       message: message,
                       user_audit_info: UserAuditInfo.new(user_email: nil, user_guid: nil),
                       start_after_staging: start_after_staging,
                       record_event: false)
    end

    private

    def record_audit_event(droplet, message, package, user_audit_info)
      Repositories::DropletEventRepository.record_create_by_staging(
        droplet,
        user_audit_info,
        message.audit_hash,
        package.app.name,
        package.app.space_guid,
        package.app.space.organization_guid
      )
    end

    def get_staging_details(package, lifecycle)
      space = package.space
      app = package.app
      org = space.organization

      memory_limit = get_memory_limit(lifecycle.staging_message.staging_memory_in_mb, space, org)
      disk_limit = get_disk_limit(lifecycle.staging_message.staging_disk_in_mb)
      environment_variables = @environment_builder.build(app,
        space,
        lifecycle,
        memory_limit,
        disk_limit,
        lifecycle.staging_message.environment_variables)

      staging_details = Diego::StagingDetails.new
      staging_details.package = package
      staging_details.staging_memory_in_mb = memory_limit
      staging_details.staging_disk_in_mb = disk_limit
      staging_details.environment_variables = environment_variables
      staging_details.lifecycle = lifecycle
      staging_details.isolation_segment = IsolationSegmentSelector.for_space(space)

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
