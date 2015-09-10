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

    encrypt :credentials, salt: :salt

    def validate
      validates_presence :app
      validates_presence :service_instance
      validates_unique [:app_id, :service_instance_id]

      validate_app_and_service_instance(app, service_instance)
      validate_cannot_change_binding
    end

    def validate_app_and_service_instance(app, service_instance)
      if app && service_instance
        unless service_instance.space == app.space
          raise InvalidAppAndServiceRelation.new(
            "'#{app.space.name}' '#{service_instance.space.name}'")
        end
      end
    end

    def validate_cannot_change_binding
      return if new?

      app_change = column_change(:app_id)
      errors.add(:app, :invalid_relation) if app_change && app_change[0] != app_change[1]

      service_change = column_change(:service_instance_id)
      errors.add(:service_instance, :invalid_relation) if service_change && service_change[0] != service_change[1]
    end

    def to_hash(opts={})
      if !VCAP::CloudController::SecurityContext.admin? && !app.space.has_developer?(VCAP::CloudController::SecurityContext.current_user)
        opts.merge!({ redact: ['credentials'] })
      end
      super(opts)
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

    def self.user_visibility_filter(user)
      { service_instance: ServiceInstance.user_visible(user) }
    end

    def credentials_with_serialization=(val)
      self.credentials_without_serialization = MultiJson.dump(val)
    end
    alias_method_chain :credentials=, 'serialization'

    def credentials_with_serialization
      string = credentials_without_serialization
      return if string.blank?
      MultiJson.load string
    end
    alias_method_chain :credentials, 'serialization'

    def gateway_data=(val)
      val = MultiJson.dump(val)
      super(val)
    end

    def gateway_data
      val = super
      val = MultiJson.load(val) if val
      val
    end

    def required_parameters
      { app_guid: app_guid }
    end

    def logger
      @logger ||= Steno.logger('cc.models.service_binding')
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
