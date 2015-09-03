require 'services/api'
require 'controllers/services/lifecycle/service_instance_binding_manager'

module VCAP::CloudController
  class ServiceBindingsController < RestController::ModelController
    define_attributes do
      to_one :app
      to_one :service_instance
      attribute :binding_options, Hash, default: {}
      attribute :parameters, Hash, default: nil
    end

    get path,      :enumerate
    get path_guid, :read

    query_parameters :app_guid, :service_instance_guid

    def self.dependencies
      [:services_event_repository]
    end

    def inject_dependencies(dependencies)
      super
      @services_event_repository = dependencies.fetch(:services_event_repository)
    end

    post path, :create
    def create
      @request_attrs = self.class::CreateMessage.decode(body).extract(stringify_keys: true)
      logger.debug 'cc.create', model: self.class.model_class_name, attributes: request_attrs
      raise InvalidRequest unless request_attrs

      service_instance_guid = request_attrs['service_instance_guid']
      app_guid              = request_attrs['app_guid']
      binding_attrs         = request_attrs.except('parameters')
      arbitrary_parameters  = request_attrs['parameters']

      binding_manager = ServiceInstanceBindingManager.new(@services_event_repository, self, logger)

      service_binding = binding_manager.create_app_service_instance_binding(service_instance_guid, app_guid, binding_attrs, arbitrary_parameters)
      @services_event_repository.record_service_binding_event(:create, service_binding)

      [HTTP::CREATED,
       { 'Location' => "#{self.class.path}/#{service_binding.guid}" },
       object_renderer.render_json(self.class, service_binding, @opts)
      ]
    rescue ServiceInstanceBindingManager::ServiceInstanceNotFound
      raise VCAP::Errors::ApiError.new_from_details('ServiceInstanceNotFound', @request_attrs['service_instance_guid'])
    rescue ServiceInstanceBindingManager::ServiceInstanceNotBindable
      raise VCAP::Errors::ApiError.new_from_details('UnbindableService')
    rescue ServiceInstanceBindingManager::AppNotFound
      raise VCAP::Errors::ApiError.new_from_details('AppNotFound', @request_attrs['app_guid'])
    end

    delete path_guid, :delete
    def delete(guid)
      service_binding = find_guid_and_validate_access(:delete, guid, ServiceBinding)
      raise_if_has_associations!(service_binding) if v2_api? && !recursive?

      binding_manager = ServiceInstanceBindingManager.new(@services_event_repository, self, logger)
      delete_job = binding_manager.delete_service_instance_binding(service_binding, params)

      if delete_job
        [HTTP::ACCEPTED, JobPresenter.new(delete_job).to_json]
      else
        [HTTP::NO_CONTENT, nil]
      end
    end

    private

    def self.translate_validation_exception(e, attributes)
      unique_errors = e.errors.on([:app_id, :service_instance_id])
      if unique_errors && unique_errors.include?(:unique)
        Errors::ApiError.new_from_details('ServiceBindingAppServiceTaken', "#{attributes['app_guid']} #{attributes['service_instance_guid']}")
      elsif e.errors.on(:app) && e.errors.on(:app).include?(:presence)
        Errors::ApiError.new_from_details('AppNotFound', attributes['app_guid'])
      elsif e.errors.on(:service_instance) && e.errors.on(:service_instance).include?(:presence)
        Errors::ApiError.new_from_details('ServiceInstanceNotFound', attributes['service_instance_guid'])
      else
        Errors::ApiError.new_from_details('ServiceBindingInvalid', e.errors.full_messages)
      end
    end

    define_messages
  end
end
