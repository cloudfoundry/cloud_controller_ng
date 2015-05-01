require 'cloud_controller/backends/staging_memory_calculator'
require 'cloud_controller/backends/staging_disk_calculator'
require 'cloud_controller/backends/staging_environment_builder'

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

    def stage(package, app, space, org, buildpack, staging_message, stagers)
      raise InvalidPackage.new('Cannot stage package whose state is not ready.') if package.state != PackageModel::READY_STATE
      raise InvalidPackage.new('Cannot stage package whose type is not bits.') if package.type != PackageModel::BITS_TYPE

      memory_limit = get_memory_limit(staging_message.memory_limit, space, org)
      disk_limit   = get_disk_limit(staging_message.disk_limit)
      stack        = get_stack(staging_message.stack)
      environment_variables = @environment_builder.build(app, space, stack, memory_limit, disk_limit)

      droplet = DropletModel.create(
        app_guid:              app.guid,
        buildpack_git_url:     staging_message.buildpack_git_url,
        buildpack_guid:        buildpack.try(:guid),
        package_guid:          package.guid,
        state:                 DropletModel::PENDING_STATE,
        environment_variables: environment_variables
      )
      logger.info("droplet created: #{droplet.guid}")

      logger.info("staging package: #{package.inspect}")
      stagers.stager_for_package(package).stage_package(
        droplet,
        stack,
        memory_limit,
        disk_limit,
        buildpack.try(:key),
        staging_message.buildpack_git_url
      )
      logger.info("package staged: #{package.inspect}")

      droplet
    end

    private

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
