module VCAP::CloudController
  class RestagesController < RestController::ModelController
    def self.dependencies
      [:app_event_repository]
    end

    path_base 'apps'
    model_class_name :App

    def inject_dependencies(dependencies)
      super
      @app_event_repository = dependencies.fetch(:app_event_repository)
    end

    post "#{path_guid}/restage", :restage

    def restage(guid)
      app = find_guid_and_validate_access(:read, guid)

      model.db.transaction do
        app.lock!

        if app.pending?
          raise CloudController::Errors::ApiError.new_from_details('NotStaged')
        end

        app.restage!
      end

      @app_event_repository.record_app_restage(app, SecurityContext.current_user.guid, SecurityContext.current_user_email)

      [
        HTTP::CREATED,
        { 'Location' => "#{self.class.path}/#{app.guid}" },
        object_renderer.render_json(self.class, app, @opts)
      ]
    end

    def self.translate_validation_exception(e, attributes)
      docker_errors = e.errors.on(:docker)
      return CloudController::Errors::ApiError.new_from_details('DockerDisabled') if docker_errors

      CloudController::Errors::ApiError.new_from_details('StagingError', e.errors.full_messages)
    end
  end
end
