module VCAP::CloudController
  class ServiceKey < Sequel::Model
    class InvalidAppAndServiceRelation < StandardError; end

    many_to_one :service_instance

    one_to_one :service_key_operation

    one_to_many :labels, class: 'VCAP::CloudController::ServiceKeyLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::ServiceKeyAnnotationModel', key: :resource_guid, primary_key: :guid
    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    export_attributes :name, :service_instance_guid, :credentials

    import_attributes :name, :service_instance_guid, :credentials

    delegate :service, :service_plan, to: :service_instance

    plugin :after_initialize

    set_field_as_encrypted :credentials

    def credhub_reference?
      !!credhub_reference
    end

    def credhub_reference
      credentials.present? ? credentials['credhub-ref'] : nil
    end

    def in_suspended_org?
      space.in_suspended_org?
    end

    def space
      service_instance.space
    end

    def validate
      validates_presence :name
      validates_presence :service_instance
      validates_unique [:name, :service_instance_id]

      if service_instance
        MaxServiceKeysPolicy.new(
          self,
          ServiceKey.filter(service_instance: space.organization.service_instances).count,
          space.organization.quota_definition,
          :service_keys_quota_exceeded
        ).validate
        MaxServiceKeysPolicy.new(
          self,
          ServiceKey.filter(service_instance: space.service_instances).count,
          space.space_quota_definition,
          :service_keys_space_quota_exceeded
        ).validate
      end
    end

    def credentials_with_serialization=(val)
      self.credentials_without_serialization = MultiJson.dump(val)
    end
    alias_method 'credentials_without_serialization=', 'credentials='
    alias_method 'credentials=', 'credentials_with_serialization='

    def credentials_with_serialization
      string = credentials_without_serialization
      return if string.blank?

      MultiJson.load string
    end
    alias_method 'credentials_without_serialization', 'credentials'
    alias_method 'credentials', 'credentials_with_serialization'

    def self.user_visibility_filter(user)
      { service_instance: ServiceInstance.dataset.filter({ space: user.spaces_dataset }) }
    end

    def after_initialize
      super
      self.guid ||= SecureRandom.uuid
    end

    def logger
      @logger ||= Steno.logger('cc.models.service_key')
    end

    def last_operation
      service_key_operation
    end

    def terminal_state?
      !service_key_operation || (%w(succeeded failed).include? service_key_operation.state)
    end

    def operation_in_progress?
      !!service_key_operation && service_key_operation.state == 'in progress'
    end

    def save_with_attributes_and_new_operation(attributes, operation)
      ServiceKey.db.transaction do
        self.lock!
        set(attributes.except(:parameters, :route_services_url, :endpoints))
        save_changes

        if self.last_operation
          self.last_operation.destroy
        end

        # it is important to create the service key operation with the service key
        # instead of doing self.service_key_operation = x
        # because mysql will deadlock when requests happen concurrently otherwise.
        ServiceKeyOperation.create(operation.merge(service_key_id: self.id))
        self.service_key_operation(reload: true)
      end
      self
    end
  end
end
