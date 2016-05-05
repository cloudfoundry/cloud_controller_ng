module VCAP::CloudController
  class ServiceBindingModel < Sequel::Model(:v3_service_bindings)
    include Serializer

    many_to_one :service_instance
    many_to_one :app, class: 'VCAP::CloudController::AppModel'

    encrypt :credentials, salt: :salt
    serializes_via_json :credentials

    encrypt :volume_mounts, salt: :volume_mounts_salt
    serializes_via_json :volume_mounts

    delegate :client, :service, :service_plan,
      to: :service_instance

    plugin :after_initialize

    def validate
      validates_presence :service_instance
      validates_presence :app
      validates_presence :type
      validates_unique [:service_instance, :app]
      validate_space_match
      validate_cannot_change_binding

      validates_max_length 65_535, :volume_mounts if !volume_mounts.nil?
    end

    def required_parameters
      { app_guid: app.guid }
    end

    def after_initialize
      super
      self.guid ||= SecureRandom.uuid
    end

    def space
      service_instance.space
    end

    private

    def validate_space_match
      return unless service_instance && app

      unless service_instance.space == app.space
        errors.add(:service_instance, :space_mismatch)
      end
    end

    def validate_cannot_change_binding
      return if new?

      app_change = column_change(:app_id)
      errors.add(:app, :invalid_relation) if app_change && app_change[0] != app_change[1]

      service_change = column_change(:service_instance_id)
      errors.add(:service_instance, :invalid_relation) if service_change && service_change[0] != service_change[1]
    end
  end
end
