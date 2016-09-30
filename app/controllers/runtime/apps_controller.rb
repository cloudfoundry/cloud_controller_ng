require 'presenters/system_env_presenter'
require 'queries/v2/app_query'
require 'actions/v2/app_stage'
require 'actions/v2/app_create'
require 'actions/v2/app_update'

module VCAP::CloudController
  class AppsController < RestController::ModelController
    def self.dependencies
      [:app_event_repository, :droplet_blobstore, :stagers, :upload_handler]
    end

    define_attributes do
      attribute :enable_ssh,              Message::Boolean, default: nil
      attribute :buildpack,               String,           default: nil
      attribute :command,                 String,           default: nil
      attribute :console,                 Message::Boolean, default: false
      attribute :diego,                   Message::Boolean, default: nil
      attribute :docker_image,            String,           default: nil
      attribute :docker_credentials_json, Hash,             default: {}, redact_in: [:create, :update]
      attribute :debug,                   String,           default: nil
      attribute :disk_quota,              Integer,          default: nil
      attribute :environment_json,        Hash,             default: {}
      attribute :health_check_type,       String,           default: 'port'
      attribute :health_check_timeout,    Integer,          default: nil
      attribute :instances,               Integer,          default: 1
      attribute :memory,                  Integer,          default: nil
      attribute :name,                    String
      attribute :production,              Message::Boolean, default: false
      attribute :state,                   String,           default: 'STOPPED'
      attribute :detected_start_command,  String,           exclude_in: [:create, :update]
      attribute :ports,                   [Integer],        default: nil

      to_one :space
      to_one :stack, optional_in: :create

      to_many :routes,              exclude_in: [:create, :update], route_for: :get
      to_many :events,              exclude_in: [:create, :update], link_only: true
      to_many :service_bindings,    exclude_in: [:create, :update], route_for: [:get]
      to_many :route_mappings,      exclude_in: [:create, :update], link_only: true, route_for: :get, association_controller: :RouteMappingsController
    end

    query_parameters :name, :space_guid, :organization_guid, :diego, :stack_guid

    get '/v2/apps/:guid/env', :read_env

    def read_env(guid)
      FeatureFlag.raise_unless_enabled!(:env_var_visibility)
      app = find_guid_and_validate_access(:read_env, guid, App)
      FeatureFlag.raise_unless_enabled!(:space_developer_env_var_visibility)

      vcap_application = VCAP::VarsBuilder.new(app).to_hash

      [
        HTTP::OK,
        {},
        MultiJson.dump({
          staging_env_json:     EnvironmentVariableGroup.staging.environment_json,
          running_env_json:     EnvironmentVariableGroup.running.environment_json,
          environment_json:     app.environment_json,
          system_env_json:      SystemEnvPresenter.new(app.service_bindings).system_env,
          application_env_json: { 'VCAP_APPLICATION' => vcap_application },
        }, pretty: true)
      ]
    end

    def self.translate_validation_exception(e, attributes)
      space_and_name_errors  = e.errors.on([:space_guid, :name])
      memory_errors          = e.errors.on(:memory)
      instance_number_errors = e.errors.on(:instances)
      app_instance_limit_errors = e.errors.on(:app_instance_limit)
      state_errors           = e.errors.on(:state)
      docker_errors          = e.errors.on(:docker)
      diego_to_dea_errors    = e.errors.on(:diego_to_dea)

      if space_and_name_errors
        CloudController::Errors::ApiError.new_from_details('AppNameTaken', attributes['name'])
      elsif memory_errors
        translate_memory_validation_exception(memory_errors)
      elsif instance_number_errors
        CloudController::Errors::ApiError.new_from_details('AppInvalid', 'Number of instances less than 0')
      elsif app_instance_limit_errors
        if app_instance_limit_errors.include?(:space_app_instance_limit_exceeded)
          CloudController::Errors::ApiError.new_from_details('SpaceQuotaInstanceLimitExceeded')
        else
          CloudController::Errors::ApiError.new_from_details('QuotaInstanceLimitExceeded')
        end
      elsif state_errors
        CloudController::Errors::ApiError.new_from_details('AppInvalid', 'Invalid app state provided')
      elsif docker_errors && docker_errors.include?(:docker_disabled)
        CloudController::Errors::ApiError.new_from_details('DockerDisabled')
      elsif diego_to_dea_errors
        CloudController::Errors::ApiError.new_from_details('MultipleAppPortsMappedDiegoToDea')
      else
        CloudController::Errors::ApiError.new_from_details('AppInvalid', e.errors.full_messages)
      end
    end

    def self.translate_memory_validation_exception(memory_errors)
      if memory_errors.include?(:space_quota_exceeded)
        CloudController::Errors::ApiError.new_from_details('SpaceQuotaMemoryLimitExceeded')
      elsif memory_errors.include?(:space_instance_memory_limit_exceeded)
        CloudController::Errors::ApiError.new_from_details('SpaceQuotaInstanceMemoryLimitExceeded')
      elsif memory_errors.include?(:quota_exceeded)
        CloudController::Errors::ApiError.new_from_details('AppMemoryQuotaExceeded')
      elsif memory_errors.include?(:zero_or_less)
        CloudController::Errors::ApiError.new_from_details('AppMemoryInvalid')
      elsif memory_errors.include?(:instance_memory_limit_exceeded)
        CloudController::Errors::ApiError.new_from_details('QuotaInstanceMemoryLimitExceeded')
      end
    end

    def inject_dependencies(dependencies)
      super
      @app_event_repository = dependencies.fetch(:app_event_repository)
      @blobstore            = dependencies.fetch(:droplet_blobstore)
      @stagers              = dependencies.fetch(:stagers)
      @upload_handler       = dependencies.fetch(:upload_handler)
    end

    def delete(guid)
      app = find_guid_and_validate_access(:delete, guid)
      space = app.space

      if !recursive_delete? && app.service_bindings.present?
        raise CloudController::Errors::ApiError.new_from_details('AssociationNotEmpty', 'service_bindings', app.class.table_name)
      end

      AppDelete.new(SecurityContext.current_user.guid, SecurityContext.current_user_email).delete_without_event(app.app)

      @app_event_repository.record_app_delete_request(
        app,
        space,
        SecurityContext.current_user.guid,
        SecurityContext.current_user_email,
        recursive_delete?)

      [HTTP::NO_CONTENT, nil]
    end

    get '/v2/apps/:guid/droplet/download', :download_droplet
    def download_droplet(guid)
      app = find_guid_and_validate_access(:read, guid)
      blob_dispatcher.send_or_redirect(guid: app.current_droplet.try(:blobstore_key))
    rescue CloudController::Errors::BlobNotFound
      raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', "Droplet not found for app with guid #{app.guid}")
    end

    put '/v2/apps/:guid/droplet/upload', :upload_droplet
    def upload_droplet(guid)
      process = find_guid_and_validate_access(:update, guid)
      droplet_path = @upload_handler.uploaded_file(params, 'droplet')

      unless droplet_path
        missing_resources_message = 'missing :droplet_path'
        raise CloudController::Errors::ApiError.new_from_details('DropletUploadInvalid', missing_resources_message)
      end

      enqueued_job = nil
      DropletModel.db.transaction do
        droplet = DropletModel.create(app: process.app, state: DropletModel::PROCESSING_UPLOAD_STATE)
        BuildpackLifecycleDataModel.create(droplet: droplet)

        droplet_upload_job = Jobs::V2::UploadDropletFromUser.new(droplet_path, droplet.guid)
        enqueued_job       = Jobs::Enqueuer.new(droplet_upload_job, queue: Jobs::LocalQueue.new(config)).enqueue
      end

      [HTTP::CREATED, JobPresenter.new(enqueued_job).to_json]
    end

    def read(guid)
      obj = find_guid(guid)
      raise CloudController::Errors::ApiError.new_from_details('AppNotFound', guid) if obj.type != 'web'
      validate_access(:read, obj)
      object_renderer.render_json(self.class, obj, @opts)
    end

    private

    def blob_dispatcher
      BlobDispatcher.new(blobstore: @blobstore, controller: self)
    end

    def before_update(app)
      verify_enable_ssh(app.space)
      updated_diego_flag = request_attrs['diego']
      ports = request_attrs['ports']
      ignore_empty_ports! if ports == []
      if should_warn_about_changed_ports?(app.diego, updated_diego_flag, ports)
        add_warning('App ports have changed but are unknown. The app should now listen on the port specified by environment variable PORT.')
      end
    end

    def ignore_empty_ports!
      @request_attrs = @request_attrs.deep_dup
      @request_attrs.delete 'ports'
      @request_attrs.freeze
    end

    def should_warn_about_changed_ports?(old_diego, new_diego, ports)
      !new_diego.nil? && old_diego && !new_diego && ports.nil?
    end

    def verify_enable_ssh(space)
      app_enable_ssh = request_attrs['enable_ssh']
      global_allow_ssh = VCAP::CloudController::Config.config[:allow_app_ssh_access]
      ssh_allowed = global_allow_ssh && (space.allow_ssh || roles.admin?)

      if app_enable_ssh && !ssh_allowed
        raise CloudController::Errors::ApiError.new_from_details(
          'InvalidRequest',
          'enable_ssh must be false due to global allow_ssh setting',
          )
      end
    end

    def after_update(app)
      stager_response = app.last_stager_response
      if stager_response.respond_to?(:streaming_log_url) && stager_response.streaming_log_url
        set_header('X-App-Staging-Log', stager_response.streaming_log_url)
      end

      @app_event_repository.record_app_update(app, app.space, SecurityContext.current_user.guid, SecurityContext.current_user_email, request_attrs)
    end

    def update(guid)
      json_msg       = self.class::UpdateMessage.decode(body)
      @request_attrs = json_msg.extract(stringify_keys: true)
      logger.debug 'cc.update', guid: guid, attributes: redact_attributes(:update, request_attrs)
      raise InvalidRequest unless request_attrs

      process = find_guid(guid)
      app     = process.app

      before_update(process)

      updater = V2::AppUpdate.new(access_validator: self, stagers: @stagers)
      updater.update(app, process, request_attrs)

      after_update(process)

      [HTTP::CREATED, object_renderer.render_json(self.class, process, @opts)]
    end

    def create
      @request_attrs = self.class::CreateMessage.decode(body).extract(stringify_keys: true)
      logger.debug 'cc.create', model: self.class.model_class_name, attributes: redact_attributes(:create, request_attrs)

      space = VCAP::CloudController::Space[guid: request_attrs['space_guid']]
      verify_enable_ssh(space)

      creator = V2::AppCreate.new(access_validator: self)
      process = creator.create(request_attrs)

      @app_event_repository.record_app_create(
        process,
        process.space,
        SecurityContext.current_user.guid,
        SecurityContext.current_user_email,
        request_attrs)

      [
        HTTP::CREATED,
        { 'Location' => "#{self.class.path}/#{process.guid}" },
        object_renderer.render_json(self.class, process, @opts)
      ]
    end

    put '/v2/apps/:app_guid/routes/:route_guid', :add_route
    def add_route(app_guid, route_guid)
      logger.debug 'cc.association.add', guid: app_guid, association: 'routes', other_guid: route_guid
      @request_attrs = { 'route' => route_guid, verb: 'add', relation: 'routes', related_guid: route_guid }

      app = find_guid(app_guid, App)
      validate_access(:read_related_object_for_update, app, request_attrs)

      before_update(app)

      route = Route.find(guid: request_attrs['route'])
      raise CloudController::Errors::ApiError.new_from_details('RouteNotFound', route_guid) unless route

      begin
        V2::RouteMappingCreate.new(SecurityContext.current_user, SecurityContext.current_user_email, route, app).add(request_attrs)
      rescue RouteMappingCreate::DuplicateRouteMapping
        # the route is already mapped, consider the request successful
      rescue V2::RouteMappingCreate::TcpRoutingDisabledError
        raise CloudController::Errors::ApiError.new_from_details('TcpRoutingDisabled')
      rescue V2::RouteMappingCreate::RouteServiceNotSupportedError
        raise CloudController::Errors::InvalidRouteRelation.new("#{route.guid} - Route services are only supported for apps on Diego")
      rescue RouteMappingCreate::SpaceMismatch
        raise CloudController::Errors::InvalidRouteRelation.new(route.guid)
      end

      after_update(app)

      [HTTP::CREATED, object_renderer.render_json(self.class, app, @opts)]
    end

    delete '/v2/apps/:app_guid/routes/:route_guid', :remove_route
    def remove_route(app_guid, route_guid)
      logger.debug 'cc.association.remove', guid: app_guid, association: 'routes', other_guid: route_guid
      @request_attrs = { 'route' => route_guid, verb: 'remove', relation: 'routes', related_guid: route_guid }

      process = find_guid(app_guid, App)
      validate_access(:can_remove_related_object, process, request_attrs)

      before_update(process)

      route = Route.find(guid: request_attrs['route'])
      raise CloudController::Errors::ApiError.new_from_details('RouteNotFound', route_guid) unless route

      route_mapping = RouteMappingModel.find(app: process.app, route: route, process: process)
      RouteMappingDelete.new(SecurityContext.current_user, SecurityContext.current_user_email).delete(route_mapping)

      after_update(process)

      [HTTP::NO_CONTENT]
    end

    delete '/v2/apps/:app_guid/service_bindings/:service_binding_guid', :remove_service_binding
    def remove_service_binding(app_guid, service_binding_guid)
      logger.debug 'cc.association.remove', guid: app_guid, association: 'service_bindings', other_guid: service_binding_guid
      @request_attrs = { 'service_binding' => service_binding_guid, verb: 'remove', relation: 'service_bindings', related_guid: service_binding_guid }

      process = find_guid(app_guid, App)
      validate_access(:can_remove_related_object, process, request_attrs)

      before_update(process)

      service_binding = ServiceBinding.find(guid: request_attrs['service_binding'])
      raise CloudController::Errors::ApiError.new_from_details('ServiceBindingNotFound', service_binding_guid) unless service_binding

      ServiceBindingDelete.new(SecurityContext.current_user.guid, SecurityContext.current_user_email).single_delete_sync(service_binding)

      after_update(process)

      [HTTP::NO_CONTENT]
    end

    def get_filtered_dataset_for_enumeration(model, ds, qp, opts)
      AppQuery.filtered_dataset_from_query_params(model, ds, qp, opts)
    end

    def filter_dataset(dataset)
      dataset.where(type: 'web')
    end

    define_messages
    define_routes
  end
end
