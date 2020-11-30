module VCAP::CloudController
  class ServiceKey < Sequel::Model
    class InvalidAppAndServiceRelation < StandardError; end

    many_to_one :service_instance

    one_to_one :service_key_operation

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

    def last_operation
      service_key_operation
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

    def operation_in_progress?
      false
    end
  end
end
