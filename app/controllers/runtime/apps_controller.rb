module VCAP::CloudController
  class AppsController < RestController::ModelController
    def self.dependencies
      [ :app_event_repository, :apps_handler ]
    end

    define_attributes do
      attribute  :buildpack,              String,           :default => nil
      attribute  :command,                String,           :default => nil
      attribute  :console,                Message::Boolean, :default => false
      attribute  :docker_image,           String,           :default => nil
      attribute  :debug,                  String,           :default => nil
      attribute  :disk_quota,             Integer,          :default => nil
      attribute  :environment_json,       Hash,             :default => {}
      attribute  :health_check_timeout,   Integer,          :default => nil
      attribute  :instances,              Integer,          :default => 1
      attribute  :memory,                 Integer,          :default => nil
      attribute  :name,                   String
      attribute  :production,             Message::Boolean, :default => false
      attribute  :state,                  String,           :default => "STOPPED"
      attribute  :detected_start_command, String,           :exclude_in => [:create, :update]

      to_one     :space
      to_one     :stack,               :optional_in => :create

      to_many    :events,              :link_only => true
      to_many    :service_bindings,    :exclude_in => :create
      to_many    :routes
    end

    query_parameters :name, :space_guid, :organization_guid

    def create
      json_msg = self.class::CreateMessage.decode(body)

      @request_attrs = json_msg.extract(stringify_keys: true)

      logger.debug "cc.create", model: self.class.model_class_name, attributes: request_attrs

      before_create

      obj = nil
      model.db.transaction do
        v3_opts = {name: request_attrs['name'], space_guid: request_attrs['space_guid']}

        v3_app_model = AppModel.create(v3_opts)
        obj = model.create_from_hash(request_attrs.merge(app_guid: v3_app_model.guid))
        validate_access(:create, obj, request_attrs)
      end

      after_create(obj)

      [
        HTTP::CREATED,
        {"Location" => "#{self.class.path}/#{obj.guid}"},
        object_renderer.render_json(self.class, obj, @opts)
      ]
    end

    def update(guid)
      json_msg = self.class::UpdateMessage.decode(body)

      @request_attrs = json_msg.extract(stringify_keys: true)

      logger.debug "cc.update", guid: guid, attributes: request_attrs
      raise InvalidRequest unless request_attrs

      obj = find_guid(guid)

      before_update(obj)

      model.db.transaction do
        obj.lock!
        validate_access(:read_for_update, obj, request_attrs)
        obj.update_from_hash(request_attrs)

        update_v3_app(obj.app_guid, obj.name) if do_v3_app_update?(request_attrs, obj)

        validate_access(:update, obj, request_attrs)
      end

      after_update(obj)

      [HTTP::CREATED, object_renderer.render_json(self.class, obj, @opts)]
    end

    get '/v2/apps/:guid/env', :read_env
    def read_env(guid)
      app = find_guid_and_validate_access(:read_env, guid, App)
      [
        HTTP::OK,
        {},
        MultiJson.dump({
          staging_env_json:     EnvironmentVariableGroup.staging.environment_json,
          running_env_json:     EnvironmentVariableGroup.running.environment_json,
          environment_json:     app.environment_json,
          system_env_json:      app.system_env_json,
          application_env_json: { 'VCAP_APPLICATION' => app.vcap_application },
        }, pretty: true)
      ]
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
      @apps_handler = dependencies.fetch(:apps_handler)
    end

    def delete(guid)
      app = find_guid_and_validate_access(:delete, guid)

      if !recursive? && app.service_bindings.present?
        raise VCAP::Errors::ApiError.new_from_details("AssociationNotEmpty", "service_bindings", app.class.table_name)
      end


      model.db.transaction do
        begin
          app.destroy
          @apps_handler.delete(app.app_guid, @access_context)
        rescue AppsHandler::DeleteWithProcesses
        end
      end

      @app_event_repository.record_app_delete_request(
          app,
          app.space,
          SecurityContext.current_user,
          SecurityContext.current_user_email,
          recursive?)

      [ HTTP::NO_CONTENT, nil ]
    end

    private

    def do_v3_app_update?(request_attrs, app)
      !(request_attrs['name'].nil? || app.app_guid.nil? || app.type != 'web')
    end

    def update_v3_app(v3_app_guid, name)
      v3_app = AppModel.find(guid: v3_app_guid)
      v3_app.name = name
      v3_app.save
    end

    def after_create(app)
      record_app_create_value = @app_event_repository.record_app_create(
          app,
          app.space,
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

      @app_event_repository.record_app_update(app, app.space, SecurityContext.current_user, SecurityContext.current_user_email, request_attrs)
    end

    define_messages
    define_routes
  end
end
