require 'services/api'

module VCAP::CloudController
  class ServiceBindingsController < RestController::ModelController
    define_attributes do
      to_one    :app
      to_one    :service_instance
      attribute :binding_options, Hash, :default => {}
    end

    query_parameters :app_guid, :service_instance_guid

    post '/v2/service_bindings', :create
    def create
      json_msg = self.class::CreateMessage.decode(body)

      @request_attrs = json_msg.extract(:stringify_keys => true)

      logger.debug "cc.create", :model => self.class.model_class_name,
        :attributes => request_attrs

      raise InvalidRequest unless request_attrs

      instance_guid = request_attrs['service_instance_guid']
      app_guid      = request_attrs['app_guid']

      validate_service_instance(instance_guid)
      validate_app(app_guid)

      binding = ServiceBinding.new(@request_attrs)
      validate_access(:create, binding, user, roles)

      binding.bind!

      [ HTTP::CREATED,
        { "Location" => "#{self.class.path}/#{binding.guid}" },
        object_renderer.render_json(self.class, binding, @opts)
      ]
    end

    def validate_app(app_guid)
      app = App.find(guid: app_guid)
      raise VCAP::Errors::ApiError.new_from_details('AppNotFound', app_guid) unless app
    end

    def validate_service_instance(instance_guid)
      service_instance = ServiceInstance.find(guid: instance_guid)

      raise VCAP::Errors::ApiError.new_from_details('ServiceInstanceNotFound', instance_guid) unless service_instance
      raise VCAP::Errors::ApiError.new_from_details('UnbindableService') unless service_instance.bindable?
    end

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    private

    def self.translate_validation_exception(e, attributes)
      unique_errors = e.errors.on([:app_id, :service_instance_id])
      if unique_errors && unique_errors.include?(:unique)
        Errors::ApiError.new_from_details("ServiceBindingAppServiceTaken", "#{attributes["app_guid"]} #{attributes["service_instance_guid"]}")
      elsif e.errors.on(:app) && e.errors.on(:app).include?(:presence)
        Errors::ApiError.new_from_details('AppNotFound', attributes['app_guid'])
      elsif e.errors.on(:service_instance) && e.errors.on(:service_instance).include?(:presence)
        Errors::ApiError.new_from_details('ServiceInstanceNotFound', attributes['service_instance_guid'])
      else
        Errors::ApiError.new_from_details("ServiceBindingInvalid", e.errors.full_messages)
      end
    end

    define_messages
    define_routes
  end
end
