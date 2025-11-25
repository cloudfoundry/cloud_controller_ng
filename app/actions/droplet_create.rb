module VCAP::CloudController
  class DropletCreate
    class Error < ::StandardError
    end

    DEFAULT_PROCESS_TYPES = { 'web' => '' }.freeze

    def create(app, message, user_audit_info)
      unless app.buildpack_lifecycle_data
        error!('Droplet creation is not available for apps with docker lifecycles.')
        return
      end

      droplet = DropletModel.new(
        app_guid: app.guid,
        state: DropletModel::AWAITING_UPLOAD_STATE,
        process_types: message.process_types || DEFAULT_PROCESS_TYPES,
        execution_metadata: ''
      )

      DropletModel.db.transaction do
        droplet.save
        VCAP::CloudController::BuildpackLifecycleDataModel.create(
          droplet:
        )
      end

      Repositories::DropletEventRepository.record_create(
        droplet,
        user_audit_info,
        app.name,
        app.space_guid,
        app.organization.guid
      )

      droplet
    end

    def create_docker_droplet(build)
      droplet = droplet_from_build(build)
      droplet.update(
        docker_receipt_username: build.package.docker_username,
        docker_receipt_password: build.package.docker_password
      )
      droplet.save

      Steno.logger('build_completed').info("droplet created: #{droplet.guid}")
      record_audit_event(droplet, build.package, user_audit_info_from_build(build))
      droplet
    end

    def find_or_create_buildpack_droplet(build)
      droplet = nil
      DropletModel.db.transaction do
        existing = DropletModel.where(build_guid: build.guid).first
        if existing
          Steno.logger('droplet_existing').info("existing droplet found: #{existing.guid}")
          if build.cnb_lifecycle?
            existing.cnb_lifecycle_data ||= build.cnb_lifecycle_data
          else
            existing.buildpack_lifecycle_data ||= build.buildpack_lifecycle_data
          end
          existing.save_changes
          return existing
        end

        droplet = droplet_from_build(build)
        droplet.save

        if build.cnb_lifecycle?
          droplet.cnb_lifecycle_data = build.cnb_lifecycle_data
        else
          droplet.buildpack_lifecycle_data = build.buildpack_lifecycle_data
        end
      end

      droplet.reload
      Steno.logger('build_completed').info("droplet created: #{droplet.guid}")
      record_audit_event(droplet, build.package, user_audit_info_from_build(build))
      droplet
    end

    private

    def droplet_from_build(build)
      DropletModel.new(
        app_guid: build.app_guid,
        package_guid: build.package_guid,
        state: DropletModel::STAGING_STATE,
        build: build
      )
    end

    def record_audit_event(droplet, package, user_audit_info)
      app = package.app
      Repositories::DropletEventRepository.record_create_by_staging(
        droplet,
        user_audit_info,
        app.name,
        app.space_guid,
        app.space.organization_guid
      )
    end

    def user_audit_info_from_build(build)
      UserAuditInfo.new(
        user_guid: build.created_by_user_guid || UserAuditInfo::DATA_UNAVAILABLE,
        user_name: build.created_by_user_name,
        user_email: build.created_by_user_email
      )
    end

    def error!(error_message)
      raise Error.new(error_message)
    end
  end
end
