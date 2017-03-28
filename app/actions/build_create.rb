module VCAP::CloudController
  class BuildCreate
    def create_and_stage(package:, lifecycle:, message:, user_audit_info:, start_after_staging: false, record_event: true)
      logger.info("creating build for package #{message.package_guid}")

      build = BuildModel.new(
        state: BuildModel::STAGING_STATE,
        package_guid: message.package_guid,
      )

      BuildModel.db.transaction do
        build.save
        # record_audit_event(build, message, user_audit_info) if record_event
      end

      staging_details = get_staging_details(package, build.guid, lifecycle)
      # TODO: staging_details.start_after_staging = start_after_staging

      logger.info("build created: #{build.guid}")
      logger.info("staging package: #{package.inspect} with build #{build.guid}")

      app = package.app
      stagers.stager_for_app(app).stage(staging_details)
      logger.info("package staging requested for #{package.guid}")

      build
    end

    private

    def get_staging_details(package, staging_guid, lifecycle)
      space = package.space

      staging_details = Diego::StagingDetails.new
      staging_details.staging_guid = staging_guid
      staging_details.package = package
      staging_details.lifecycle = lifecycle
      staging_details.isolation_segment = IsolationSegmentSelector.for_space(space)
      staging_details.environment_variables = {}

      staging_details
    end

    def logger
      @logger ||= Steno.logger('cc.action.build_create')
    end

    def stagers
      CloudController::DependencyLocator.instance.stagers
    end
  end
end
