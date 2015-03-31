module VCAP::CloudController
  class PackageStageAction
    class InvalidPackage < StandardError; end

    def stage(package, app, space, buildpack, staging_message, stagers)
      raise InvalidPackage.new('Cannot stage package whose state is not ready.') if package.state != PackageModel::READY_STATE
      raise InvalidPackage.new('Cannot stage package whose type is not bits.') if package.type != PackageModel::BITS_TYPE

      app_env = app.environment_variables || {}
      environment_variables = EnvironmentVariableGroup.staging.environment_json.merge(app_env).merge({
        VCAP_APPLICATION: vcap_application(staging_message, app, space),
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
        staging_message.memory_limit,
        staging_message.disk_limit,
        buildpack.try(:key),
        staging_message.buildpack_git_url
      )
      logger.info("package staged: #{package.inspect}")

      droplet
    end

    private

    def vcap_application(message, app_model, space)
      version = SecureRandom.uuid
      uris = app_model.routes.map(&:fqdn)
      {
        limits: {
          mem: message.memory_limit,
          disk: message.disk_limit,
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

    def logger
      @logger ||= Steno.logger('cc.package_stage_action')
    end
  end
end
