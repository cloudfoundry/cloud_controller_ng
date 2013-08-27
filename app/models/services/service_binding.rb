module VCAP::CloudController::Models
  class ServiceBinding < Sequel::Model
    class InvalidAppAndServiceRelation < StandardError; end

    many_to_one :app
    many_to_one :service_instance

    default_order_by  :id

    export_attributes :app_guid, :service_instance_guid, :credentials,
                      :binding_options, :gateway_data, :gateway_name

    import_attributes :app_guid, :service_instance_guid, :credentials,
                      :binding_options, :gateway_data

    def validate
      validates_presence :app
      validates_presence :service_instance
      validates_unique [:app_id, :service_instance_id]

      # TODO: make this a standard validation
      validate_app_and_service_instance(app, service_instance)
    end

    def validate_app_and_service_instance(app, service_instance)
      if app && service_instance
        unless service_instance.space == app.space
          raise InvalidAppAndServiceRelation.new(
            "'#{app.space.name}' '#{service_instance.space.name}'")
        end
      end
    end

    def space
      service_instance.space
    end

    def before_create
      super
      raise VCAP::Errors::UnbindableService unless service_instance.bindable?
      service_instance.bind_on_gateway(self) if service_instance
    end

    def after_create
      mark_app_for_restaging
    end

    def after_update
      mark_app_for_restaging
    end

    def before_destroy
      service_instance.unbind_on_gateway(self)
      mark_app_for_restaging
    end

    def after_rollback
      service_instance.unbind_on_gateway(self) if service_instance
      super
    end

    def mark_app_for_restaging
      app.mark_for_restaging(:save => true) if app
    end

    def self.user_visibility_filter(user)
      {:service_instance => ServiceInstance.user_visible(user)}
    end

    def credentials=(val)
      json = Yajl::Encoder.encode(val)
      generate_salt
      encrypted_string = VCAP::CloudController::Encryptor.encrypt(json, salt)
      super(encrypted_string)
    end

    def credentials
      encrypted_string = super
      return unless encrypted_string
      json = VCAP::CloudController::Encryptor.decrypt(encrypted_string, salt)
      Yajl::Parser.parse(json) if json
    end

    def gateway_data=(val)
      val = Yajl::Encoder.encode(val)
      super(val)
    end

    def gateway_data
      val = super
      val = Yajl::Parser.parse(val) if val
      val
    end

    def logger
      @logger ||= Steno.logger("cc.models.service_binding")
    end

    def generate_salt
      self.salt ||= VCAP::CloudController::Encryptor.generate_salt
    end

    DEFAULT_BINDING_OPTIONS = '{}'

    def binding_options
      Yajl::Parser.parse(super || DEFAULT_BINDING_OPTIONS)
    end

    def binding_options=(values)
      super(Yajl::Encoder.encode(values))
    end

  end
end
