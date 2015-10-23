require 'cloud_controller/backends/staging_memory_calculator'
require 'cloud_controller/backends/staging_disk_calculator'
require 'cloud_controller/backends/staging_environment_builder'
require 'cloud_controller/diego/traditional/v3/staging_details'

module VCAP::CloudController
  class PackageStageAction
    class InvalidPackage < StandardError; end
    class SpaceQuotaExceeded < StandardError; end
    class OrgQuotaExceeded < StandardError; end
    class DiskLimitExceeded < StandardError; end

    def initialize(memory_limit_calculator=StagingMemoryCalculator.new,
      disk_limit_calculator=StagingDiskCalculator.new,
      environment_presenter=StagingEnvironmentBuilder.new)

      @memory_limit_calculator = memory_limit_calculator
      @disk_limit_calculator   = disk_limit_calculator
      @environment_builder     = environment_presenter
    end

    def stage(package, buildpack_info, staging_message, stagers)
      raise InvalidPackage.new('Cannot stage package whose state is not ready.') if package.state != PackageModel::READY_STATE
      raise InvalidPackage.new('Cannot stage package whose type is not bits.') if package.type != PackageModel::BITS_TYPE

      staging_details = get_staging_details(package, buildpack_info, staging_message)

      droplet = DropletModel.create(
        app_guid:              package.app.guid,
        buildpack_guid:        buildpack_info.buildpack_record.try(:guid),
        package_guid:          package.guid,
        state:                 DropletModel::PENDING_STATE,
        stack_name:            staging_message.stack,
        environment_variables: staging_details.environment_variables,
        memory_limit:          staging_details.memory_limit,
        disk_limit:            staging_details.disk_limit
      )
      staging_details.droplet = droplet
      logger.info("droplet created: #{droplet.guid}")

      BuildpackLifecycleDataModel.create(
        buildpack: staging_message.lifecycle['data']['buildpack'],
        stack:     staging_message.lifecycle['data']['stack'],
        droplet:   droplet
      )

      logger.info("staging package: #{package.inspect} for droplet #{droplet.guid}")
      stagers.stager_for_package(package).stage(staging_details)
      logger.info("package staging requested: #{package.inspect}")

      droplet
    end

    private

    def get_staging_details(package, buildpack_info, staging_message)
      app   = package.app
      space = package.space
      org   = space.organization

      memory_limit          = get_memory_limit(staging_message.memory_limit, space, org)
      disk_limit            = get_disk_limit(staging_message.disk_limit)
      stack                 = get_stack(staging_message.stack)
      environment_variables = @environment_builder.build(app,
        space,
        stack,
        memory_limit,
        disk_limit,
        staging_message.environment_variables)

      staging_details                       = VCAP::CloudController::Diego::Traditional::V3::StagingDetails.new
      staging_details.stack                 = stack
      staging_details.memory_limit          = memory_limit
      staging_details.disk_limit            = disk_limit
      staging_details.buildpack_info        = buildpack_info
      staging_details.environment_variables = environment_variables

      staging_details
    end

    def get_disk_limit(requested_limit)
      @disk_limit_calculator.get_limit(requested_limit)
    rescue StagingDiskCalculator::LimitExceeded
      raise PackageStageAction::DiskLimitExceeded
    end

    def get_memory_limit(requested_limit, space, org)
      @memory_limit_calculator.get_limit(requested_limit, space, org)
    rescue StagingMemoryCalculator::SpaceQuotaExceeded
      raise PackageStageAction::SpaceQuotaExceeded
    rescue StagingMemoryCalculator::OrgQuotaExceeded
      raise PackageStageAction::OrgQuotaExceeded
    end

    def get_stack(requested_stack)
      return requested_stack if requested_stack
      Stack.default.name
    end

    def logger
      @logger ||= Steno.logger('cc.package_stage_action')
    end
  end
end
