module VCAP::CloudController
  class AppsController < RestController::ModelController
    define_attributes do
      attribute  :buildpack,           String,     :default => nil
      attribute  :command,             String,     :default => nil
      attribute  :console,             Message::Boolean, :default => false
      attribute  :docker_image,        String,     :default => nil
      attribute  :debug,               String,     :default => nil
      attribute  :disk_quota,          Integer,    :default => nil
      attribute  :environment_json,    Hash,       :default => {}
      attribute  :health_check_timeout, Integer,   :default => nil
      attribute  :instances,           Integer,    :default => 1
      attribute  :memory,              Integer,    :default => nil
      attribute  :name,                String
      attribute  :production,          Message::Boolean,    :default => false
      attribute  :state,               String,     :default => "STOPPED"

      to_one     :space
      to_one     :stack,               :optional_in => :create

      to_many    :events,              :link_only => true
      to_many    :service_bindings,    :exclude_in => :create
      to_many    :routes
    end

    query_parameters :name, :space_guid, :organization_guid

    get '/v2/apps/:guid/env', :read_env
    def read_env(guid)
      app = find_guid_and_validate_access(:read_env, guid, App)
      [HTTP::OK, {}, { system_env_json: app.system_env_json, environment_json: app.environment_json}.to_json]
    end

    def self.translate_validation_exception(e, attributes)
      space_and_name_errors  = e.errors.on([:space_id, :name])
      memory_errors          = e.errors.on(:memory)
      instance_number_errors = e.errors.on(:instances)
      state_errors           = e.errors.on(:state)

      if space_and_name_errors && space_and_name_errors.include?(:unique)
        Errors::ApiError.new_from_details("AppNameTaken", attributes["name"])
      elsif memory_errors
        if memory_errors.include?(:space_quota_exceeded)
          Errors::ApiError.new_from_details("SpaceQuotaMemoryLimitExceeded")
        elsif memory_errors.include?(:space_instance_memory_limit_exceeded)
          Errors::ApiError.new_from_details("SpaceQuotaInstanceMemoryLimitExceeded")
        elsif memory_errors.include?(:quota_exceeded)
          Errors::ApiError.new_from_details("AppMemoryQuotaExceeded")
        elsif memory_errors.include?(:zero_or_less)
          Errors::ApiError.new_from_details("AppMemoryInvalid")
        elsif memory_errors.include?(:instance_memory_limit_exceeded)
          Errors::ApiError.new_from_details("QuotaInstanceMemoryLimitExceeded")
        end
      elsif instance_number_errors
        Errors::ApiError.new_from_details("AppInvalid", "Number of instances less than 1")
      elsif state_errors
        Errors::ApiError.new_from_details("AppInvalid", "Invalid app state provided")
      else
        Errors::ApiError.new_from_details("AppInvalid", e.errors.full_messages)
      end
    end

    def inject_dependencies(dependencies)
      super
      @app_event_repository = dependencies.fetch(:app_event_repository)
    end

    def delete(guid)
      app = find_guid_and_validate_access(:delete, guid)

      if !recursive? && app.service_bindings.present?
        raise VCAP::Errors::ApiError.new_from_details("AssociationNotEmpty", "service_bindings", app.class.table_name)
      end

      @app_event_repository.record_app_delete_request(
          app,
          SecurityContext.current_user,
          SecurityContext.current_user_email,
          recursive?)
      app.destroy

      [ HTTP::NO_CONTENT, nil ]
    end

    private

    def after_create(app)
      record_app_create_value = @app_event_repository.record_app_create(
          app,
          SecurityContext.current_user,
          SecurityContext.current_user_email,
          request_attrs)
      record_app_create_value if request_attrs
    end

    def after_update(app)
      stager_response = app.last_stager_response
      if stager_response.respond_to?(:streaming_log_url) && stager_response.streaming_log_url
        set_header("X-App-Staging-Log", stager_response.streaming_log_url)
      end

      if app.dea_update_pending?
        Dea::Client.update_uris(app)
      end

      @app_event_repository.record_app_update(app, SecurityContext.current_user, SecurityContext.current_user_email, request_attrs)
    end

    define_messages
    define_routes
  end
end
