require 'cloud_controller/diego/process_guid'

module VCAP::CloudController
  class AppsSSHController < RestController::ModelController
    NON_EXISTENT_CURRENT_USER = 'unknown-user-guid'.freeze
    NON_EXISTENT_CURRENT_USER_EMAIL = 'unknown-user-email'.freeze

    # Allow unauthenticated access so that we can take action if authentication
    # fails
    allow_unauthenticated_access only: :ssh_access

    def self.dependencies
      [:app_event_repository]
    end

    def inject_dependencies(dependencies)
      super
      @app_event_repository = dependencies.fetch(:app_event_repository)
    end

    model_class_name :App

    get '/internal/apps/:guid/ssh_access', :ssh_access
    def ssh_access(guid)
      global_allow_ssh = VCAP::CloudController::Config.config[:allow_app_ssh_access]
      check_authentication(:ssh_access_internal)
      app = find_guid_and_validate_access(:read, guid)
      unless app.diego && app.enable_ssh && global_allow_ssh && app.space.allow_ssh
        raise ApiError.new_from_details('InvalidRequest')
      end
      response_body = { 'process_guid' => VCAP::CloudController::Diego::ProcessGuid.from_app(app) }
      record_ssh_authorized_event(app)
      [HTTP::OK, MultiJson.dump(response_body)]
    rescue => e
      app = App.find(guid: guid)
      record_ssh_unauthorized_event(app) unless app.nil?
      raise e
    end

    private

    def record_ssh_unauthorized_event(app)
      current_user = SecurityContext.current_user || nil
      current_user_guid = current_user.nil? ? NON_EXISTENT_CURRENT_USER : current_user.guid
      current_user_email = SecurityContext.current_user_email || NON_EXISTENT_CURRENT_USER_EMAIL
      @app_event_repository.record_app_ssh_unauthorized(app, current_user_guid, current_user_email)
    end

    def record_ssh_authorized_event(app)
      current_user = SecurityContext.current_user
      current_user_email = SecurityContext.current_user_email
      @app_event_repository.record_app_ssh_authorized(app, current_user.guid, current_user_email)
    end
  end
end
