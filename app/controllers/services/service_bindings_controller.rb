require 'vcap/services/api'
require 'controllers/services/lifecycle/service_instance_binding_manager'
require 'models/helpers/process_types'
require 'actions/v2/services/service_binding_read'
require 'actions/v2/services/service_binding_create'
require 'fetchers/service_binding_create_fetcher'

module VCAP::CloudController
  class ServiceBindingsController < RestController::ModelController
    define_attributes do
      to_one :app, association_controller: :AppsController, association_name: :v2_app
      to_one :service_instance
      attribute :binding_options, Hash, exclude_in: [:create, :update]
      attribute :parameters, Hash, default: nil
      attribute :name, String, default: nil
    end

    get path, :enumerate

    query_parameters :app_guid, :name, :service_instance_guid

    get path_guid, :read

    def read(guid)
      obj = find_guid(guid)
      raise CloudController::Errors::ApiError.new_from_details('ServiceBindingNotFound', guid) unless obj.v2_app.present?

      validate_access(:read, obj)
      object_renderer.render_json(self.class, obj, @opts)
    end

    post path, :create

    def create
      @request_attrs = self.class::CreateMessage.decode(body).extract(stringify_keys: true)
      logger.debug 'cc.create', model: self.class.model_class_name, attributes: request_attrs
      raise InvalidRequest unless request_attrs

      message = ServiceBindingCreateMessage.new({
        type: 'app',
        name: request_attrs['name'],
        relationships: {
          app: {
            data: { guid: request_attrs['app_guid'] }
          },
          service_instance: {
            data: { guid: request_attrs['service_instance_guid'] }
          },
        },
        data: {
          parameters: request_attrs['parameters']
        }
      })

      accepts_incomplete = convert_flag_to_bool(params['accepts_incomplete'])

      app, service_instance = ServiceBindingCreateFetcher.new.fetch(message.app_guid, message.service_instance_guid)
      permissions = Permissions.new(SecurityContext.current_user)

      raise CloudController::Errors::ApiError.new_from_details('AppNotFound', @request_attrs['app_guid']) unless app
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceNotFound', @request_attrs['service_instance_guid']) unless service_instance
      raise CloudController::Errors::ApiError.new_from_details('NotAuthorized') unless permissions.can_write_to_active_space?(app.space.id)
      raise CloudController::Errors::ApiError.new_from_details('OrgSuspended') unless permissions.is_space_active?(app.space.id)

      creator = ServiceBindingCreate.new(UserAuditInfo.from_context(SecurityContext))
      service_binding = creator.create(app, service_instance, message, volume_services_enabled?, accepts_incomplete)
      warn_if_user_provided_service_has_parameters!(service_instance)

      [
        status_from_operation_state(service_binding.last_operation),
        { 'Location' => "#{self.class.path}/#{service_binding.guid}" },
        object_renderer.render_json(self.class, service_binding, @opts)
      ]
    rescue ServiceBindingCreate::ServiceInstanceNotBindable
      raise CloudController::Errors::ApiError.new_from_details('UnbindableService')
    rescue ServiceBindingCreate::VolumeMountServiceDisabled
      raise CloudController::Errors::ApiError.new_from_details('VolumeMountServiceDisabled')
    rescue ServiceBindingCreate::ServiceBrokerInvalidBindingsRetrievable
      raise CloudController::Errors::ApiError.new_from_details('ServiceBindingInvalid', 'Could not create asynchronous binding when bindings_retrievable is false.')
    rescue ServiceBindingCreate::ServiceBrokerRespondedAsyncWhenNotAllowed
      raise CloudController::Errors::ApiError.new_from_details('ServiceBrokerRespondedAsyncWhenNotAllowed')
    rescue ServiceBindingCreate::InvalidServiceBinding => e
      raise CloudController::Errors::ApiError.new_from_details('ServiceBindingAppServiceTaken', e.message)
    end

    delete path_guid, :delete

    def delete(guid)
      service_binding = ServiceBinding.find(guid: guid)
      permissions = Permissions.new(SecurityContext.current_user)

      raise CloudController::Errors::ApiError.new_from_details('ServiceBindingNotFound', guid) unless service_binding
      raise CloudController::Errors::ApiError.new_from_details('NotAuthorized') unless permissions.can_write_to_active_space?(service_binding.space.id)
      raise CloudController::Errors::ApiError.new_from_details('OrgSuspended') unless permissions.is_space_active?(service_binding.space.id)

      accepts_incomplete = convert_flag_to_bool(params['accepts_incomplete'])

      deleter = ServiceBindingDelete.new(UserAuditInfo.from_context(SecurityContext), accepts_incomplete)

      if async? && !accepts_incomplete
        job = deleter.background_delete_request(service_binding)
        [HTTP::ACCEPTED, JobPresenter.new(job).to_json]
      else
        warnings = deleter.foreground_delete_request(service_binding)

        add_warnings_from_binding_delete!(warnings)

        if accepts_incomplete && service_binding.exists?
          [HTTP::ACCEPTED,
           { 'Location' => "#{self.class.path}/#{service_binding.guid}" },
           object_renderer.render_json(self.class, service_binding, @opts)
          ]
        else
          [HTTP::NO_CONTENT, nil]
        end
      end
    end

    get '/v2/service_bindings/:guid/parameters', :parameters
    def parameters(guid)
      binding = find_guid_and_validate_access(:read, guid)
      raise CloudController::Errors::ApiError.new_from_details('ServiceBindingNotFound', guid) unless binding.v2_app.present?

      fetcher = ServiceBindingRead.new
      begin
        parameters = fetcher.fetch_parameters(binding)
        [HTTP::OK, parameters.to_json]
      rescue ServiceBindingRead::NotSupportedError
        raise CloudController::Errors::ApiError.new_from_details('ServiceFetchBindingParametersNotSupported')
      rescue LockCheck::ServiceBindingLockedError => e
        raise CloudController::Errors::ApiError.new_from_details('AsyncServiceBindingOperationInProgress', e.service_binding.app.name, e.service_binding.service_instance.name)
      end
    end

    def self.translate_validation_exception(e, _attributes)
      CloudController::Errors::ApiError.new_from_details('ServiceBindingInvalid', e.errors.full_messages)
    end

    define_messages

    private

    def filter_dataset(dataset)
      dataset.select_all(ServiceBinding.table_name).join(ProcessModel.table_name, app_guid: :app_guid, type: ProcessTypes::WEB)
    end

    def volume_services_enabled?
      @config.get(:volume_services_enabled)
    end

    def warn_if_user_provided_service_has_parameters!(service_instance)
      if service_instance.user_provided_instance? && @request_attrs['parameters'] && @request_attrs['parameters'].any?
        add_warning('Configuration parameters are ignored for bindings to user-provided service instances.')
      end
    end

    def add_warnings_from_binding_delete!(warnings)
      warnings.each do |warning|
        add_warning(warning)
      end
    end

    def status_from_operation_state(last_operation)
      if last_operation&.state == 'in progress'
        HTTP::ACCEPTED
      else
        HTTP::CREATED
      end
    end
  end
end
