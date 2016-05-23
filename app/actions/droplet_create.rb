require 'cloud_controller/backends/staging_memory_calculator'
require 'cloud_controller/backends/staging_disk_calculator'
require 'cloud_controller/backends/staging_environment_builder'
require 'cloud_controller/diego/v3/staging_details'
require 'cloud_controller/diego/lifecycles/lifecycle_provider'
require 'repositories/droplet_event_repository'

module VCAP::CloudController
  class DropletCreate
    class InvalidPackage < StandardError; end
    class SpaceQuotaExceeded < StandardError; end
    class OrgQuotaExceeded < StandardError; end
    class DiskLimitExceeded < StandardError; end

    def initialize(memory_limit_calculator=StagingMemoryCalculator.new,
      disk_limit_calculator=StagingDiskCalculator.new,
      environment_presenter=StagingEnvironmentBuilder.new,
      actor:,
      actor_email:)

      @memory_limit_calculator = memory_limit_calculator
      @disk_limit_calculator   = disk_limit_calculator
      @environment_builder     = environment_presenter
      @actor = actor
      @actor_name = actor_email
    end

    def create_and_stage(package, lifecycle, message)
      raise InvalidPackage.new('Cannot stage package whose state is not ready.') if package.state != PackageModel::READY_STATE

      staging_details = get_staging_details(package, lifecycle)

      droplet = DropletModel.new({
        app_guid:              package.app.guid,
        package_guid:          package.guid,
        state:                 DropletModel::PENDING_STATE,
        environment_variables: staging_details.environment_variables,
        staging_memory_in_mb:  staging_details.staging_memory_in_mb,
        staging_disk_in_mb:    staging_details.staging_disk_in_mb
      }.merge(lifecycle.pre_known_receipt_information))

      DropletModel.db.transaction do
        droplet.save
        staging_details.droplet = droplet
        lifecycle.create_lifecycle_data_model(droplet)

        Repositories::DropletEventRepository.record_create_by_staging(
          droplet,
          @actor,
          @actor_name,
          message.audit_hash,
          package.app.name,
          package.app.space_guid,
          package.app.space.organization_guid
          )
      end

      load_association(droplet)

      logger.info("droplet created: #{droplet.guid}")

      logger.info("staging package: #{package.inspect} for droplet #{droplet.guid}")
      stagers.stager_for_package(package, lifecycle.type).stage(staging_details)
      logger.info("package staging requested: #{package.inspect}")

      droplet
    end

    private

    def load_association(droplet)
      droplet.reload
    end

    def get_staging_details(package, lifecycle)
      staging_message = lifecycle.staging_message
      app   = package.app
      space = package.space
      org   = space.organization

      memory_limit          = get_memory_limit(staging_message.staging_memory_in_mb, space, org)
      disk_limit            = get_disk_limit(staging_message.staging_disk_in_mb)
      environment_variables = @environment_builder.build(app,
        space,
        lifecycle,
        memory_limit,
        disk_limit,
        staging_message.environment_variables)

      staging_details                       = VCAP::CloudController::Diego::V3::StagingDetails.new
      staging_details.staging_memory_in_mb  = memory_limit
      staging_details.staging_disk_in_mb    = disk_limit
      staging_details.environment_variables = environment_variables
      staging_details.lifecycle             = lifecycle

      staging_details
    end

    def get_disk_limit(requested_limit)
      @disk_limit_calculator.get_limit(requested_limit)
    rescue StagingDiskCalculator::LimitExceeded
      raise DiskLimitExceeded
    end

    def get_memory_limit(requested_limit, space, org)
      @memory_limit_calculator.get_limit(requested_limit, space, org)
    rescue StagingMemoryCalculator::SpaceQuotaExceeded
      raise SpaceQuotaExceeded
    rescue StagingMemoryCalculator::OrgQuotaExceeded
      raise OrgQuotaExceeded
    end

    def logger
      @logger ||= Steno.logger('cc.package_stage_action')
    end

    def stagers
      CloudController::DependencyLocator.instance.stagers
    end
  end
end
