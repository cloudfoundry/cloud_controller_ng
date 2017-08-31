require 'cloud_controller/backends/quota_validating_staging_memory_calculator'
require 'cloud_controller/backends/staging_disk_calculator'
require 'cloud_controller/backends/staging_environment_builder'
require 'cloud_controller/diego/staging_details'
require 'cloud_controller/diego/lifecycles/lifecycle_provider'
require 'repositories/app_usage_event_repository'

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
    class StagingInProgress < BuildError
    end

    attr_reader :staging_response

    def initialize(user_audit_info: UserAuditInfo.from_context(SecurityContext),
      memory_limit_calculator: QuotaValidatingStagingMemoryCalculator.new,
      disk_limit_calculator: StagingDiskCalculator.new,
      environment_presenter: StagingEnvironmentBuilder.new)

      @user_audit_info         = user_audit_info
      @memory_limit_calculator = memory_limit_calculator
      @disk_limit_calculator   = disk_limit_calculator
      @environment_builder     = environment_presenter
    end

    def create_and_stage(package:, lifecycle:, start_after_staging: false)
      logger.info("creating build for package #{package.guid}")
      staging_in_progress! if package.app.staging_in_progress?
      raise InvalidPackage.new('Cannot stage package whose state is not ready.') if package.state != PackageModel::READY_STATE

      staging_details                     = get_staging_details(package, lifecycle)
      staging_details.start_after_staging = start_after_staging

      build = BuildModel.new(
        state:                 BuildModel::STAGING_STATE,
        package_guid:          package.guid,
        app:                   package.app,
        created_by_user_guid:  @user_audit_info.user_guid,
        created_by_user_name:  @user_audit_info.user_name,
        created_by_user_email: @user_audit_info.user_email
      )

      BuildModel.db.transaction do
        build.save
        staging_details.staging_guid = build.guid
        lifecycle.create_lifecycle_data_model(build)

        raise CloudController::Errors::ApiError.new_from_details('CustomBuildpacksDisabled') if using_disabled_custom_buildpack?(build)

        Repositories::AppUsageEventRepository.new.create_from_build(build, 'STAGING_STARTED')
        app = package.app
        Repositories::BuildEventRepository.record_build_create(build,
          @user_audit_info,
          app.name,
          app.space_guid,
          app.organization_guid)
      end

      logger.info("build created: #{build.guid}")
      logger.info("staging package: #{package.inspect} for build #{build.guid}")
      @staging_response = stagers.stager_for_app.stage(staging_details)
      logger.info("package staging requested: #{package.inspect}")

      build
    end

    alias_method :create_and_stage_without_event, :create_and_stage

    private

    def using_disabled_custom_buildpack?(build)
      build.lifecycle_data.using_custom_buildpack? && custom_buildpacks_disabled?
    end

    def custom_buildpacks_disabled?
      VCAP::CloudController::Config.config.get(:disable_custom_buildpacks)
    end

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

    def staging_in_progress!
      raise StagingInProgress
    end
  end
end
