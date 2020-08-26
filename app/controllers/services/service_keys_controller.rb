require 'vcap/services/api'

module VCAP::CloudController
  class ServiceKeysController < RestController::ModelController
    define_attributes do
      to_one :service_instance
      attribute :name, String
      attribute :parameters, Hash, default: nil
    end

    get path, :enumerate

    query_parameters :name, :service_instance_guid

    def self.not_found_exception(guid, _find_model)
      CloudController::Errors::ApiError.new_from_details('ServiceKeyNotFound', guid)
    end

    def self.dependencies
      [:services_event_repository, :service_key_credential_object_renderer, :service_key_credential_collection_renderer]
    end

    def inject_dependencies(dependencies)
      super
      @services_event_repository = dependencies.fetch(:services_event_repository)
      @object_renderer = dependencies[:service_key_credential_object_renderer]
      @collection_renderer = dependencies[:service_key_credential_collection_renderer]
    end

    post path, :create
    def create
      @request_attrs = self.class::CreateMessage.decode(body).extract(stringify_keys: true)
      logger.debug 'cc.create', model: self.class.model_class_name, attributes: request_attrs
      raise InvalidRequest unless request_attrs

      service_key_manager = ServiceKeyManager.new(@services_event_repository, self, logger)
      service_key = service_key_manager.create_service_key(@request_attrs)

      @services_event_repository.record_service_key_event(:create, service_key)

      [HTTP::CREATED,
       { 'Location' => "#{self.class.path}/#{service_key.guid}" },
       object_renderer.render_json(self.class, service_key, @opts)
      ]
    rescue ServiceKeyManager::ServiceInstanceNotFound
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceNotFound', @request_attrs['service_instance_guid'])
    rescue ServiceKeyManager::ServiceInstanceNotBindable
      error_message = "This service doesn't support creation of keys."
      raise CloudController::Errors::ApiError.new_from_details('ServiceKeyNotSupported', error_message)
    rescue ServiceKeyManager::ServiceInstanceUserProvided
      error_message = 'Service keys are not supported for user-provided service instances.'
      raise CloudController::Errors::ApiError.new_from_details('ServiceKeyNotSupported', error_message)
    end

    delete path_guid, :delete
    def delete(guid)
      begin
        service_key = find_guid_and_validate_access(:delete, guid, ServiceKey)
      rescue CloudController::Errors::ApiError => e
        e.name == 'NotAuthorized' ? raise(CloudController::Errors::ApiError.new_from_details('ServiceKeyNotFound', guid)) : raise(e)
      end

      key_manager = ServiceKeyManager.new(@services_event_repository, self, logger)
      key_manager.delete_service_key(service_key)

      [HTTP::NO_CONTENT, nil]
    end

    get '/v2/service_keys/:guid', :read
    def read(guid)
      begin
        service_key = find_guid_and_validate_access(:read, guid, ServiceKey)
      rescue CloudController::Errors::ApiError => e
        e.name == 'NotAuthorized' ? raise(CloudController::Errors::ApiError.new_from_details('ServiceKeyNotFound', guid)) : raise(e)
      end

      [HTTP::OK,
       { 'Location' => "#{self.class.path}/#{service_key.guid}" },
       object_renderer.render_json(self.class, service_key, @opts)
      ]
    end

    get '/v2/service_keys/:guid/parameters', :parameters
    def parameters(guid)
      service_key = find_guid_and_validate_access(:read, guid)

      fetcher = ServiceBindingRead.new
      parameters = fetcher.fetch_parameters(service_key)
      [HTTP::OK, parameters.to_json]
    rescue ServiceBindingRead::NotSupportedError
      raise CloudController::Errors::ApiError.new_from_details('ServiceKeyNotSupported', 'This service does not support fetching service key parameters.')
    rescue LockCheck::ServiceBindingLockedError => e
      raise CloudController::Errors::ApiError.new_from_details('AsyncServiceBindingOperationInProgress', e.service_binding.app.name, e.service_binding.service_instance.name)
    rescue CloudController::Errors::ApiError => e
      e.name == 'NotAuthorized' ? raise(CloudController::Errors::ApiError.new_from_details('ServiceKeyNotFound', guid)) : raise(e)
    end

    def self.translate_validation_exception(e, attributes)
      unique_errors = e.errors.on([:name, :service_instance_id])
      if unique_errors && unique_errors.include?(:unique)
        CloudController::Errors::ApiError.new_from_details('ServiceKeyNameTaken', attributes['name'])
      elsif e.errors.on(:service_instance) && e.errors.on(:service_instance).include?(:presence)
        CloudController::Errors::ApiError.new_from_details('ServiceInstanceNotFound', attributes['service_instance_guid'])
      else
        CloudController::Errors::ApiError.new_from_details('ServiceKeyInvalid', e.errors.full_messages)
      end
    end

    define_messages
  end
end
