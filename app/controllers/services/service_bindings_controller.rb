require 'services/api'
require 'controllers/services/lifecycle/service_instance_binding_manager'
require 'models/helpers/process_types'

module VCAP::CloudController
  class ServiceBindingsController < RestController::ModelController
    define_attributes do
      to_one :app, association_controller: :AppsController, association_name: :v2_app
      to_one :service_instance
      attribute :binding_options, Hash, exclude_in: [:create, :update]
      attribute :parameters, Hash, default: nil
    end

    get path, :enumerate

    query_parameters :app_guid, :service_instance_guid

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

      app, service_instance = ServiceBindingCreateFetcher.new.fetch(message.app_guid, message.service_instance_guid)
      raise CloudController::Errors::ApiError.new_from_details('AppNotFound', @request_attrs['app_guid']) unless app
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceNotFound', @request_attrs['service_instance_guid']) unless service_instance
      raise CloudController::Errors::ApiError.new_from_details('NotAuthorized') unless Permissions.new(SecurityContext.current_user).can_write_to_space?(app.space_guid)

      creator = ServiceBindingCreate.new(UserAuditInfo.from_context(SecurityContext))
      service_binding = creator.create(app, service_instance, message, volume_services_enabled?)

      [HTTP::CREATED,
       { 'Location' => "#{self.class.path}/#{service_binding.guid}" },
       object_renderer.render_json(self.class, service_binding, @opts)
      ]
    rescue ServiceBindingCreate::ServiceInstanceNotBindable
      raise CloudController::Errors::ApiError.new_from_details('UnbindableService')
    rescue ServiceBindingCreate::VolumeMountServiceDisabled
      raise CloudController::Errors::ApiError.new_from_details('VolumeMountServiceDisabled')
    rescue ServiceBindingCreate::InvalidServiceBinding
      raise CloudController::Errors::ApiError.new_from_details('ServiceBindingAppServiceTaken', "#{app.guid} #{service_instance.guid}")
    end

    delete path_guid, :delete

    def delete(guid)
      binding = ServiceBinding.find(guid: guid)
      raise CloudController::Errors::ApiError.new_from_details('ServiceBindingNotFound', guid) unless binding
      raise CloudController::Errors::ApiError.new_from_details('NotAuthorized') unless Permissions.new(SecurityContext.current_user).can_write_to_space?(binding.space.guid)

      deleter = ServiceBindingDelete.new(UserAuditInfo.from_context(SecurityContext))

      if async?
        job = deleter.single_delete_async(binding)
        [HTTP::ACCEPTED, JobPresenter.new(job).to_json]
      else
        deleter.single_delete_sync(binding)
        [HTTP::NO_CONTENT, nil]
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
  end
end
