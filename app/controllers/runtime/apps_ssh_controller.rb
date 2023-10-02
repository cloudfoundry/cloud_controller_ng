require 'cloud_controller/diego/process_guid'

module VCAP::CloudController
  class AppsSSHController < RestController::ModelController
    NON_EXISTENT_CURRENT_USER       = 'unknown-user-guid'.freeze
    NON_EXISTENT_CURRENT_USER_EMAIL = 'unknown-user-email'.freeze

    # Allow unauthenticated access so that we can take action if authentication
    # fails
    allow_unauthenticated_access only: %i[ssh_access ssh_access_with_index]

    def self.dependencies
      [:app_event_repository]
    end

    def inject_dependencies(dependencies)
      super
      @app_event_repository = dependencies.fetch(:app_event_repository)
    end

    model_class_name :ProcessModel
    self.not_found_exception_name = 'AppNotFound'

    get '/internal/apps/:guid/ssh_access/:index', :ssh_access_with_index

    def ssh_access_with_index(guid, index)
      index = 'unknown' if index.nil?

      check_authentication(:ssh_access_internal)
      process = find_guid_and_validate_access(:update, guid)
      raise ApiError.new_from_details('InvalidRequest') unless VCAP::CloudController::AppSshEnabled.new(process).enabled?

      record_ssh_authorized_event(process, index)

      response_body = { 'process_guid' => VCAP::CloudController::Diego::ProcessGuid.from_process(process) }
      [HTTP::OK, MultiJson.dump(response_body)]
    rescue StandardError => e
      process = ProcessModel.find(guid:)
      record_ssh_unauthorized_event(process, index) unless process.nil?
      raise e
    end

    private

    def record_ssh_unauthorized_event(process, index)
      current_user       = SecurityContext.current_user || nil
      current_user_guid  = current_user.nil? ? NON_EXISTENT_CURRENT_USER : current_user.guid
      current_user_email = SecurityContext.current_user_email || NON_EXISTENT_CURRENT_USER_EMAIL
      user_audit_info    = UserAuditInfo.new(user_guid: current_user_guid, user_email: current_user_email)
      @app_event_repository.record_app_ssh_unauthorized(process, user_audit_info, index)
    end

    def record_ssh_authorized_event(process, index)
      @app_event_repository.record_app_ssh_authorized(process, UserAuditInfo.from_context(SecurityContext), index)
    end
  end
end
