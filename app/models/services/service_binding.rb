require 'models/helpers/process_types'

module VCAP::CloudController
  class ServiceBinding < Sequel::Model
    include Serializer

    plugin :after_initialize

    many_to_one :app, class: 'VCAP::CloudController::AppModel', key: :app_guid, primary_key: :guid, without_guid_generation: true
    many_to_one :service_instance, key: :service_instance_guid, primary_key: :guid, without_guid_generation: true

    one_through_one :v2_app,
      class: 'VCAP::CloudController::ProcessModel',
      join_table:        AppModel.table_name,
      left_primary_key:  :app_guid, left_key: :guid,
      right_primary_key: :app_guid, right_key: :guid,
      conditions: { type: ProcessTypes::WEB }

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
      validates_presence :type

      validates_unique [:app_guid, :service_instance_guid]

      validate_space_match
      validate_cannot_change_binding

      validates_max_length 65_535, :volume_mounts if volume_mounts.present?
      validates_max_length 10_000, :syslog_drain_url, allow_nil: true

      errors.add(:app, :invalid_relation) unless app.is_a?(AppModel)
    end

    def validate_space_match
      return unless service_instance && app

      unless service_instance.space == app.space
        errors.add(:service_instance, :space_mismatch)
      end
    end

    def validate_cannot_change_binding
      return if new?

      app_change = column_change(:app_guid)
      errors.add(:app, :invalid_relation) if app_change && app_change[0] != app_change[1]

      service_change = column_change(:service_instance_guid)
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
  end
end
