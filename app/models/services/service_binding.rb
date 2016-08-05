module VCAP::CloudController
  class ServiceBinding < Sequel::Model
    include Serializer

    class InvalidAppAndServiceRelation < StandardError; end

    plugin :after_initialize

    many_to_one :app
    many_to_one :service_instance

    encrypt :credentials, salt: :salt
    serializes_via_json :credentials

    encrypt :volume_mounts, salt: :volume_mounts_salt
    serializes_via_json :volume_mounts

    import_attributes :app_guid, :service_instance_guid, :credentials, :syslog_drain_url

    delegate :client, :service, :service_plan,
      to: :service_instance

    def validate
      validates_presence :app
      validates_presence :service_instance
      validates_unique [:app_id, :service_instance_id]
      validates_max_length 65_535, :volume_mounts if !volume_mounts.nil?

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

    def to_hash(_opts={})
      { guid: guid }
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

    def required_parameters
      { app_guid: app_guid }
    end

    def logger
      @logger ||= Steno.logger('cc.models.service_binding')
    end
  end
end
