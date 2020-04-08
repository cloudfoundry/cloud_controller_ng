require 'actions/v2/app_stage'
require 'actions/staging_cancel'
require 'controllers/runtime/mixins/find_process_through_app'

module VCAP::CloudController
  class RestagesController < RestController::ModelController
    include FindProcessThroughApp

    def self.dependencies
      [:app_event_repository, :stagers]
    end

    path_base 'apps'
    model_class_name :ProcessModel
    self.not_found_exception_name = 'AppNotFound'

    def inject_dependencies(dependencies)
      super
      @app_event_repository = dependencies.fetch(:app_event_repository)
      @stagers              = dependencies.fetch(:stagers)
    end

    post "#{path_guid}/restage", :restage

    def restage(guid)
      process = find_guid_and_validate_access(:read_for_update, guid)

      validate_process!(process)

      model.db.transaction do
        process.app.lock!
        process.lock!

        V2::AppStop.stop(process.app, StagingCancel.new(@stagers))
        process.app.update(droplet_guid: nil)
        AppStart.start_without_event(process.app, create_revision: false)
      end
      V2::AppStage.new(stagers: @stagers).stage(process)

      @app_event_repository.record_app_restage(process, UserAuditInfo.from_context(SecurityContext))

      TelemetryLogger.v2_emit(
        'restage-app',
        {
          'app-id' => process.app.guid,
          'user-id' => current_user.guid,
        }, {
        'lifecycle' => process.app.lifecycle_type,
        'buildpacks' => process.app.lifecycle_data.buildpacks,
        'stack' => process.app.lifecycle_data.stack
      }
      )

      [
        HTTP::CREATED,
        { 'Location' => "#{self.class.path}/#{process.guid}" },
        object_renderer.render_json(self.class, process, @opts)
      ]
    rescue AppStart::InvalidApp => e
      raise CloudController::Errors::ApiError.new_from_details('DockerDisabled') if e.message.match?(/docker_disabled/)

      raise CloudController::Errors::ApiError.new_from_details('StagingError', e.message)
    rescue AppStop::InvalidApp => e
      raise CloudController::Errors::ApiError.new_from_details('StagingError', e.message)
    end

    private

    def validate_process!(process)
      unless process.web?
        raise CloudController::Errors::ApiError.new_from_details('AppNotFound', process.guid)
      end

      if process.instances < 1
        raise CloudController::Errors::ApiError.new_from_details('StagingError', 'App must have at least 1 instance to stage.')
      end

      if process.pending?
        raise CloudController::Errors::ApiError.new_from_details('NotStaged')
      end

      if process.latest_package.nil?
        raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid', 'bits have not been uploaded')
      end
    end
  end
end
