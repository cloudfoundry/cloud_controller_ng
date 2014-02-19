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
      raise VCAP::Errors::UnbindableService unless service_bindable?

      binding = ServiceBinding.new(@request_attrs)
      validate_access(:create, binding, user, roles)

      binding.bind!

      [ HTTP::CREATED,
        { "Location" => "#{self.class.path}/#{binding.guid}" },
        object_renderer.render_json(self.class, binding, @opts)
      ]
    end

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    private

    def self.translate_validation_exception(e, attributes)
      unique_errors = e.errors.on([:app_id, :service_instance_id])
      if unique_errors && unique_errors.include?(:unique)
        Errors::ServiceBindingAppServiceTaken.new("#{attributes["app_guid"]} #{attributes["service_instance_guid"]}")
      else
        Errors::ServiceBindingInvalid.new(e.errors.full_messages)
      end
    end

    def service_bindable?
      service_instance = ServiceInstance.find(:guid => request_attrs['service_instance_guid'])
      service_instance.bindable?
    end

    define_messages
    define_routes
  end
end
