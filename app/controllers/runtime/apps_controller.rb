module VCAP::CloudController
  class AppsController < RestController::ModelController
    define_attributes do
      attribute  :name,                String
      attribute  :production,          Message::Boolean,    :default => false

      to_one     :space
      to_one     :stack,               :optional_in => :create

      attribute  :environment_json,    Hash,       :default => {}
      attribute  :system_env_json,     Hash,       :default => {}
      attribute  :memory,              Integer,    :default => nil
      attribute  :instances,           Integer,    :default => 1
      attribute  :disk_quota,          Integer,    :default => 1024

      attribute  :state,               String,     :default => "STOPPED"
      attribute  :command,             String,     :default => nil
      attribute  :console,             Message::Boolean, :default => false
      attribute  :debug,               String,     :default => nil
      attribute  :health_check_timeout, Integer,   :default => nil

      attribute  :buildpack,           String, :default => nil
      attribute  :detected_buildpack,  String, :exclude_in => [:create, :update]

      to_many    :service_bindings,    :exclude_in => :create
      to_many    :routes

      to_many    :events,              :link_only => true
    end

    query_parameters :name, :space_guid, :organization_guid

    def self.translate_validation_exception(e, attributes)
      space_and_name_errors = e.errors.on([:space_id, :name])
      memory_quota_errors = e.errors.on(:memory)
      instance_number_errors = e.errors.on(:instances)

      if space_and_name_errors && space_and_name_errors.include?(:unique)
        Errors::AppNameTaken.new(attributes["name"])
      elsif memory_quota_errors
        if memory_quota_errors.include?(:quota_exceeded)
          Errors::AppMemoryQuotaExceeded.new
        elsif memory_quota_errors.include?(:zero_or_less)
          Errors::AppMemoryInvalid.new
        end
      elsif instance_number_errors
        Errors::AppInvalid.new("Number of instances less than 0")
      else
        Errors::AppInvalid.new(e.errors.full_messages)
      end
    end

    def inject_dependencies(dependencies)
      @app_event_repository = dependencies.fetch(:app_event_repository)
    end

    def delete(guid)
      app = find_guid_and_validate_access(:delete, guid)

      if !recursive? && app.service_bindings.present?
        raise VCAP::Errors::AssociationNotEmpty.new("service_bindings", app.class.table_name)
      end

      @app_event_repository.record_app_delete_request(app, SecurityContext.current_user, recursive?)
      app.destroy

      [ HTTP::NO_CONTENT, nil ]
    end

    private

    def after_create(app)
      record_app_create_value = @app_event_repository.record_app_create(app, SecurityContext.current_user, request_attrs)
      record_app_create_value if request_attrs
    end

    def after_update(app)
      stager_response = app.last_stager_response
      if stager_response && stager_response.streaming_log_url
        set_header("X-App-Staging-Log", stager_response.streaming_log_url)
      end

      if app.dea_update_pending?
        DeaClient.update_uris(app)
      end

      @app_event_repository.record_app_update(app, SecurityContext.current_user, request_attrs)
    end

    define_messages
    define_routes
  end
end
