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
      bind_on_gateway
    end

    def after_create
      mark_app_for_restaging
    end

    def after_update
      mark_app_for_restaging
    end

    def before_destroy
      unbind_on_gateway
      mark_app_for_restaging
    end

    def after_rollback
      unbind_on_gateway if @bound_on_gateway
      super
    end

    def after_commit
      @bound_on_gateway = false
    end

    def mark_app_for_restaging
      app.mark_for_restaging(:save => true) if app
    end

    def self.user_visibility_filter(user)
      user_visibility_filter_with_admin_override(
        :service_instance => ServiceInstance.user_visible)
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

    def service_gateway_client
      # this shouldn't happen under normal circumstances, but will if we are
      # running tests that bypass validations
      return unless service_instance
      service_instance.service_gateway_client
    end

    def bind_on_gateway
      client = service_gateway_client

      # TODO: see service_gateway_client
      unless client
        self.gateway_name = ""
        self.gateway_data = nil
        self.credentials = {}
        return
      end

      logger.debug "binding service on gateway for #{guid}"

      service = service_instance.service_plan.service
      gw_attrs = client.bind(
        :service_id => service_instance.gateway_name,
        # TODO: we shouldn't still be using this compound label
        :label      => "#{service.label}-#{service.version}",
        :email      => VCAP::CloudController::SecurityContext.
                             current_user_email,
        :binding_options => binding_options,
      )

      logger.debug "binding response for #{guid} #{gw_attrs.inspect}"

      self.gateway_name = gw_attrs.service_id
      self.gateway_data = gw_attrs.configuration
      self.credentials  = gw_attrs.credentials

      @bound_on_gateway = true
    end

    def unbind_on_gateway
      client = service_gateway_client
      return unless client # TODO see service_gateway_client
      client.unbind(
        :service_id      => service_instance.gateway_name,
        :handle_id       => gateway_name,
        :binding_options => binding_options,
      )
    rescue => e
      logger.error "unbind failed #{e}"
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

    def binding_options=(bo)
      super(Yajl::Encoder.encode(bo))
    end

  end
end
