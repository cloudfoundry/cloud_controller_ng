require 'models/helpers/process_types'
require 'models/runtime/helpers/service_operation_mixin'

module VCAP::CloudController
  class ServiceBinding < Sequel::Model
    include Serializer
    include ServiceOperationMixin

    plugin :after_initialize

    one_to_one :service_binding_operation

    one_to_many :labels, class: 'VCAP::CloudController::ServiceBindingLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::ServiceBindingAnnotationModel', key: :resource_guid, primary_key: :guid
    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    many_to_one :app, class: 'VCAP::CloudController::AppModel', key: :app_guid, primary_key: :guid, without_guid_generation: true
    many_to_one :service_instance, key: :service_instance_guid, primary_key: :guid, without_guid_generation: true

    one_through_one :v2_app,
                    class: 'VCAP::CloudController::ProcessModel',
                    join_table: AppModel.table_name,
                    left_primary_key: :app_guid, left_key: :guid,
                    right_primary_key: :app_guid, right_key: :guid,
                    conditions: { type: ProcessTypes::WEB }

    set_field_as_encrypted :credentials
    serializes_via_json :credentials

    set_field_as_encrypted :volume_mounts, salt: :volume_mounts_salt
    serializes_via_json :volume_mounts

    import_attributes :app_guid, :service_instance_guid, :credentials, :syslog_drain_url, :name

    delegate :service, :service_plan, to: :service_instance

    def around_save
      yield
    rescue Sequel::UniqueConstraintViolation => e
      if e.message.include?('unique_service_binding_app_guid_name')
        errors.add(%i[app_guid name], :unique)
        raise validation_failed_error
      elsif e.message.include?('unique_service_binding_service_instance_guid_app_guid')
        errors.add(%i[service_instance_guid app_guid], :unique)
        raise validation_failed_error
      else
        raise e
      end
    end

    def validate
      validates_presence :app
      validates_presence :service_instance
      validates_presence :type

      validates_unique %i[app_guid service_instance_guid], message: Sequel.lit('The app is already bound to the service.')
      validates_unique %i[app_guid name], message: Sequel.lit("The binding name is invalid. App binding names must be unique. The app already has a binding with name '#{name}'.")

      validate_space_match
      validate_cannot_change_binding

      validates_max_length 65_535, :volume_mounts if volume_mounts.present?
      validates_max_length 10_000, :syslog_drain_url, allow_nil: true
      validates_max_length 255, :name, allow_nil: true, message: Sequel.lit('The binding name is invalid. App binding names must be less than 256 characters.')

      validates_format(/\A(\w|-)+\z/, :name, message: Sequel.lit('The binding name is invalid. Valid characters are alphanumeric, underscore, and dash.')) if name.present?

      errors.add(:app, :invalid_relation) unless app.is_a?(AppModel)
    end

    def validate_space_match
      return unless service_instance && app
      return if service_instance.space == app.space

      return unless service_instance.shared_spaces.exclude?(app.space)

      errors.add(:service_instance, :space_mismatch)
    end

    def validate_cannot_change_binding
      return if new?

      app_change = column_change(:app_guid)
      errors.add(:app, :invalid_relation) if app_change && app_change[0] != app_change[1]

      service_change = column_change(:service_instance_guid)
      errors.add(:service_instance, :invalid_relation) if service_change && service_change[0] != service_change[1]
    end

    def to_hash(_opts={})
      { guid: }
    end

    delegate :in_suspended_org?, to: :space

    delegate :space, to: :app

    delegate :name, to: :service_instance, prefix: true

    def after_initialize
      super
      self.guid ||= SecureRandom.uuid
    end

    def before_update
      encode_syslog_drain_url_commas
      super
    end

    def before_create
      encode_syslog_drain_url_commas
      super
    end

    def encode_syslog_drain_url_commas
      return unless syslog_drain_url

      self.syslog_drain_url = syslog_drain_url.gsub(',', '%2c')
    end

    def self.user_visibility_filter(user)
      { app: AppModel.user_visible(user) }
    end

    def last_operation
      service_binding_operation
    end

    def save_with_attributes_and_new_operation(attributes, operation)
      save_with_new_operation(operation, attributes:)
      self
    end

    def save_with_new_operation(last_operation, attributes: {})
      ServiceBinding.db.transaction do
        lock!
        set(attributes.except(:parameters, :route_services_url, :endpoints))
        save_changes

        self.last_operation.destroy if self.last_operation

        # it is important to create the service binding operation with the service binding
        # instead of doing self.service_binding_operation = x
        # because mysql will deadlock when requests happen concurrently otherwise.
        ServiceBindingOperation.create(last_operation.merge(service_binding_id: id))
        service_binding_operation(reload: true)
      end
    end
  end
end
