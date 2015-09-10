require 'services/api'

module VCAP::CloudController
  class ServiceKeysController < RestController::ModelController
    define_attributes do
      to_one :service_instance
      attribute :name, String
      attribute :parameters, Hash, default: nil
    end

    get path,      :enumerate

    query_parameters :name, :service_instance_guid

    def self.not_found_exception(guid)
      Errors::ApiError.new_from_details('ServiceKeyNotFound', guid)
    end

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
      service_key_manager = ServiceKeyManager.new(@services_event_repository, self, logger)
      service_key = service_key_manager.create_service_key(@request_attrs)

      @services_event_repository.record_service_key_event(:create, service_key)

      [HTTP::CREATED,
       { 'Location' => "#{self.class.path}/#{service_key.guid}" },
       object_renderer.render_json(self.class, service_key, @opts)
      ]
    rescue ServiceKeyManager::ServiceInstanceNotFound
      raise VCAP::Errors::ApiError.new_from_details('ServiceInstanceNotFound', @request_attrs['service_instance_guid'])
    rescue ServiceKeyManager::ServiceInstanceNotBindable
      error_message = "This service doesn't support creation of keys."
      raise VCAP::Errors::ApiError.new_from_details('ServiceKeyNotSupported', error_message)
    rescue ServiceKeyManager::ServiceInstanceVersionMismatch
      error_message = 'Service keys are not supported for this service. ' \
        'The service broker implements the v1 Service Broker API which has been deprecated. '\
        'To generate credentials, try binding an application to the service instance.'
      raise VCAP::Errors::ApiError.new_from_details('ServiceKeyNotSupported', error_message)
    rescue ServiceKeyManager::ServiceInstanceUserProvided
      error_message = 'Service keys are not supported for user-provided service instances.'
      raise VCAP::Errors::ApiError.new_from_details('ServiceKeyNotSupported', error_message)
    end

    delete path_guid, :delete
    def delete(guid)
      begin
        service_key = find_guid_and_validate_access(:delete, guid, ServiceKey)
      rescue VCAP::Errors::ApiError => e
        e.name == 'NotAuthorized' ? raise(VCAP::Errors::ApiError.new_from_details('ServiceKeyNotFound', guid)) : raise(e)
      end

      key_manager = ServiceKeyManager.new(@services_event_repository, self, logger)
      key_manager.delete_service_key(service_key)

      [HTTP::NO_CONTENT, nil]
    end

    get '/v2/service_keys/:guid', :read
    def read(guid)
      begin
        service_key = find_guid_and_validate_access(:read, guid, ServiceKey)
      rescue VCAP::Errors::ApiError => e
        e.name == 'NotAuthorized' ? raise(VCAP::Errors::ApiError.new_from_details('ServiceKeyNotFound', guid)) : raise(e)
      end

      [HTTP::OK,
       { 'Location' => "#{self.class.path}/#{service_key.guid}" },
       object_renderer.render_json(self.class, service_key, @opts)
      ]
    end

    private

    def self.translate_validation_exception(e, attributes)
      unique_errors = e.errors.on([:name, :service_instance_id])
      if unique_errors && unique_errors.include?(:unique)
        Errors::ApiError.new_from_details('ServiceKeyNameTaken', "#{attributes['name']}")
      elsif e.errors.on(:service_instance) && e.errors.on(:service_instance).include?(:presence)
        Errors::ApiError.new_from_details('ServiceInstanceNotFound', attributes['service_instance_guid'])
      else
        Errors::ApiError.new_from_details('ServiceKeyInvalid', e.errors.full_messages)
      end
    end

    define_messages
  end
end
