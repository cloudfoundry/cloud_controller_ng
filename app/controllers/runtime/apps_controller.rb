module VCAP::CloudController
  rest_controller :Apps do
    define_attributes do
      attribute  :name,                String
      attribute  :production,          Message::Boolean,    :default => false

      to_one     :space
      to_one     :stack,               :optional_in => :create

      attribute  :environment_json,    Hash,       :default => {}
      attribute  :memory,              Integer,    :default => 256
      attribute  :instances,           Integer,    :default => 1
      attribute  :disk_quota,          Integer,    :default => 1024

      attribute  :state,               String,     :default => "STOPPED"
      attribute  :command,             String,     :default => nil
      attribute  :console,             Message::Boolean, :default => false
      attribute  :debug,               String,     :default => nil

      attribute  :buildpack,           String, :default => nil
      attribute  :detected_buildpack,  String, :exclude_in => [:create, :update]

      to_many    :service_bindings,    :exclude_in => :create
      to_many    :routes

      to_many    :events
    end

    query_parameters :name, :space_guid, :organization_guid

    def self.translate_validation_exception(e, attributes)
      space_and_name_errors = e.errors.on([:space_id, :name])
      memory_quota_errors = e.errors.on(:memory)

      if space_and_name_errors && space_and_name_errors.include?(:unique)
        Errors::AppNameTaken.new(attributes["name"])
      elsif memory_quota_errors
        if memory_quota_errors.include?(:quota_exceeded)
          Errors::AppMemoryQuotaExceeded.new
        elsif memory_quota_errors.include?(:zero_or_less)
          Errors::AppMemoryInvalid.new
        end
      else
        Errors::AppInvalid.new(e.errors.full_messages)
      end
    end

    # Override this method because we want to enable the concept of
    # deleted apps. This is necessary because we have an app events table
    # which is a foreign key constraint on apps. Thus, we can't actually delete
    # the app itself, but instead mark it as deleted.
    #
    # @param [String] guid The GUID of the object to delete.
    def delete(guid)
      app = find_guid_and_validate_access(:delete, guid)
      Event.record_app_delete(app, SecurityContext.current_user)

      recursive = params["recursive"] == "true"
      if !recursive && app.service_bindings.present?
        raise VCAP::Errors::AssociationNotEmpty.new("service_bindings", app.class.table_name)
      end

      app.db.transaction(savepoint: true) do
        app.soft_delete
      end

      [ HTTP::NO_CONTENT, nil ]
    end

    def update(guid)
      app = find_for_update(guid)
      Event.record_app_update(app, SecurityContext.current_user, request_attrs)

      model.db.transaction(savepoint: true) do
        app.lock!
        app.update_from_hash(request_attrs)
        Loggregator.emit(guid, "Updated app with guid #{guid}")
      end

      after_update(app)

      [HTTP::CREATED, serialization.render_json(self.class, app, @opts)]
    end

    def create
      json_msg = self.class::CreateMessage.decode(body)

      @request_attrs = json_msg.extract(:stringify_keys => true)

      logger.debug "cc.create", :model => self.class.model_class_name,
        :attributes => request_attrs

      raise InvalidRequest unless request_attrs

      obj = nil
      model.db.transaction(savepoint: true) do
        obj = model.create_from_hash(request_attrs)
        validate_access(:create, obj, user, roles)
        Event.record_app_create(obj, SecurityContext.current_user)
      end

      after_create(obj)
      Loggregator.emit(obj.guid, "Created app with guid #{obj.guid}")

      [ HTTP::CREATED,
        { "Location" => "#{self.class.path}/#{obj.guid}" },
        serialization.render_json(self.class, obj, @opts)
      ]
    end

    private

    def after_update(app)
      stager_response = app.last_stager_response
      if stager_response && stager_response.streaming_log_url
        set_header("X-App-Staging-Log", stager_response.streaming_log_url)
      end

      if app.dea_update_pending?
        DeaClient.update_uris(app)
      end
    end
  end
end
