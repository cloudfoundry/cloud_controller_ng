require 'cloud_controller/backends/staging_memory_calculator'
require 'cloud_controller/backends/staging_disk_calculator'

module VCAP::CloudController
  class PackageStageAction
    class InvalidPackage < StandardError; end
    class SpaceQuotaExceeded < StandardError; end
    class OrgQuotaExceeded < StandardError; end
    class DiskLimitExceeded < StandardError; end

    def initialize(memory_limit_calculator=StagingMemoryCalculator.new, disk_limit_calculator=StagingDiskCalculator.new)
      @memory_limit_calculator = memory_limit_calculator
      @disk_limit_calculator   = disk_limit_calculator
    end

    def stage(package, app, space, org, buildpack, staging_message, stagers)
      raise InvalidPackage.new('Cannot stage package whose state is not ready.') if package.state != PackageModel::READY_STATE
      raise InvalidPackage.new('Cannot stage package whose type is not bits.') if package.type != PackageModel::BITS_TYPE

      memory_limit = get_memory_limit(staging_message.memory_limit, space, org)
      disk_limit = get_disk_limit(staging_message.disk_limit)

      app_env = app.environment_variables || {}
      environment_variables = EnvironmentVariableGroup.staging.environment_json.merge(app_env).merge({
        VCAP_APPLICATION: vcap_application(app, space, memory_limit, disk_limit),
        CF_STACK: staging_message.stack
      })

      droplet = DropletModel.create(
        app_guid: app.guid,
        buildpack_git_url: staging_message.buildpack_git_url,
        buildpack_guid: buildpack.try(:guid),
        package_guid: package.guid,
        state: DropletModel::PENDING_STATE,
        environment_variables: environment_variables
      )
      logger.info("droplet created: #{droplet.guid}")

      logger.info("staging package: #{package.inspect}")
      stagers.stager_for_package(package).stage_package(
        droplet,
        staging_message.stack,
        memory_limit,
        disk_limit,
        buildpack.try(:key),
        staging_message.buildpack_git_url
      )
      logger.info("package staged: #{package.inspect}")

      droplet
    end

    private

    def vcap_application(app_model, space, memory_limit, disk_limit)
      version = SecureRandom.uuid
      uris = app_model.routes.map(&:fqdn)
      {
        limits: {
          mem: memory_limit,
          disk: disk_limit,
          fds: Config.config[:instance_file_descriptor_limit] || 16384,
        },
        application_version: version,
        application_name: app_model.name,
        application_uris: uris,
        version: version,
        name: app_model.name,
        space_name: space.name,
        space_id: space.guid,
        uris: uris,
        users: nil
      }
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

    def logger
      @logger ||= Steno.logger('cc.package_stage_action')
    end
  end
end
