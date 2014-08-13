module VCAP::CloudController
  class ServiceBinding < Sequel::Model
    class InvalidAppAndServiceRelation < StandardError; end

    many_to_one :app
    many_to_one :service_instance

    export_attributes :app_guid, :service_instance_guid, :credentials,
                      :binding_options, :gateway_data, :gateway_name, :syslog_drain_url

    import_attributes :app_guid, :service_instance_guid, :credentials,
                      :binding_options, :gateway_data, :syslog_drain_url

    alias_attribute :broker_provided_id, :gateway_name

    delegate :client, :service, :service_plan,
      to: :service_instance

    plugin :after_initialize

    def validate
      validates_presence :app
      validates_presence :service_instance
      validates_unique [:app_id, :service_instance_id]

      validate_logging_service_binding if service_instance.respond_to?(:service_plan)

      validate_app_and_service_instance(app, service_instance)
    end

    def validate_logging_service_binding
      return if syslog_drain_url.blank?

      service_advertised_as_logging_service = service_instance.service_plan.service.requires.include?("syslog_drain")
      raise VCAP::Errors::ApiError.new_from_details("InvalidLoggingServiceBinding") unless service_advertised_as_logging_service
    end

    def validate_app_and_service_instance(app, service_instance)
      if app && service_instance
        unless service_instance.space == app.space
          raise InvalidAppAndServiceRelation.new(
            "'#{app.space.name}' '#{service_instance.space.name}'")
        end
      end
    end

    def to_hash(opts={})
      if !VCAP::CloudController::SecurityContext.admin? && !app.space.developers.include?(VCAP::CloudController::SecurityContext.current_user)
        opts.merge!({redact: ['credentials']})
      end
      super(opts)
    end


    def bind!
      client.bind(self)

      begin
        save
      rescue => e
        safe_unbind
        raise e
      end
    end

    def in_suspended_org?
      app.in_suspended_org?
    end

    def space
      service_instance.space
    end

    def after_initialize
      super
      self.guid ||= SecureRandom.uuid
    end

    def before_destroy
      client.unbind(self)
      super
    end

    def self.user_visibility_filter(user)
      {:service_instance => ServiceInstance.user_visible(user)}
    end

    def credentials=(val)
      json = MultiJson.dump(val)
      generate_salt
      encrypted_string = VCAP::CloudController::Encryptor.encrypt(json, salt)
      super(encrypted_string)
    end

    def credentials
      encrypted_string = super
      return unless encrypted_string
      json = VCAP::CloudController::Encryptor.decrypt(encrypted_string, salt)
      MultiJson.load(json) if json
    end

    def gateway_data=(val)
      val = MultiJson.dump(val)
      super(val)
    end

    def gateway_data
      val = super
      val = MultiJson.load(val) if val
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
      MultiJson.load(super || DEFAULT_BINDING_OPTIONS)
    end

    def binding_options=(values)
      super(MultiJson.dump(values))
    end

    private

    def safe_unbind
      client.unbind(self)
    rescue => unbind_e
      logger.error "Unable to unbind #{self}: #{unbind_e}"
    end

  end
end
