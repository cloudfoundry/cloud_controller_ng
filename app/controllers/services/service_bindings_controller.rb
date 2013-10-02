require 'services/api'

module VCAP::CloudController
  rest_controller :ServiceBindings do
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

      binding = ServiceBinding.new(@request_attrs)
      validate_access(:create, binding, user, roles)

      client = binding.client
      client.bind(binding)

      begin
        binding.save
      rescue => e
        begin
          # this needs to go into a retry queue
          client.unbind(binding)
        rescue => unbind_e
          logger.error "Unable to unbind #{binding}: #{unbind_e}"
        end

        raise e
      end

      [ HTTP::CREATED,
        { "Location" => "#{self.class.path}/#{binding.guid}" },
        serialization.render_json(self.class, binding, @opts)
      ]
    end

    def self.translate_validation_exception(e, attributes)
      unique_errors = e.errors.on([:app_id, :service_instance_id])
      if unique_errors && unique_errors.include?(:unique)
        Errors::ServiceBindingAppServiceTaken.new(
          "#{attributes["app_guid"]} #{attributes["service_instance_guid"]}")
      else
        Errors::ServiceBindingInvalid.new(e.errors.full_messages)
      end
    end
  end
end
