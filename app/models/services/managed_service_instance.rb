require 'vcap/request'
require 'models/runtime/helpers/service_operation_mixin'

module VCAP::CloudController
  class ManagedServiceInstance < ServiceInstance
    include ServiceOperationMixin

    INITIAL_STRING = 'initial'.freeze
    IN_PROGRESS_STRING = 'in progress'.freeze

    many_to_one :service_plan

    export_attributes :name, :credentials, :service_plan_guid,
                      :space_guid, :gateway_data, :dashboard_url, :type, :last_operation,
                      :tags, :maintenance_info

    import_attributes :name, :service_plan_guid,
                      :space_guid, :gateway_data, :maintenance_info

    strip_attributes :name

    plugin :after_initialize

    serialize_attributes :json, :maintenance_info, :broker_provided_metadata

    def validation_policies
      if space
        [
          MaxServiceInstancePolicy.new(self, organization.managed_service_instances_dataset.count, organization.quota_definition, :service_instance_quota_exceeded),
          MaxServiceInstancePolicy.new(self, space.managed_service_instances_dataset.count, space.space_quota_definition, :service_instance_space_quota_exceeded),
          PaidServiceInstancePolicy.new(self, organization.quota_definition, :paid_services_not_allowed_by_quota),
          PaidServiceInstancePolicy.new(self, space.space_quota_definition, :paid_services_not_allowed_by_space_quota)
        ]
      else
        []
      end
    end

    def validate
      super
      validates_presence :service_plan
      validation_policies.map(&:validate)
    end

    def valid_with_plan?(new_plan)
      old_plan = service_plan
      self.service_plan = new_plan
      is_valid = valid?
      self.service_plan = old_plan
      is_valid
    end

    def after_initialize
      super
      self.guid ||= SecureRandom.uuid
    end

    def as_summary_json
      super.merge(
        'last_operation' => last_operation.try(:to_hash),
        'dashboard_url' => dashboard_url,
        'shared_from' => nil,
        'shared_to' => [],
        'service_broker_name' => service_broker.name,
        'maintenance_info' => maintenance_info || {},
        'service_plan' => {
          'guid' => service_plan.guid,
          'name' => service_plan.name,
          'maintenance_info' => service_plan.maintenance_info || {},
          'service' => {
            'guid' => service.guid,
            'label' => service.label,
            'provider' => service.provider,
            'version' => service.version
          }
        }
      )
    end

    def to_hash(opts={})
      return super if last_operation.nil?

      last_operation_hash = last_operation.to_hash({})
      super.merge!('last_operation' => last_operation_hash)
    end

    def gateway_data=(val)
      str = Oj.dump(val)
      super(str)
    end

    def gateway_data
      val = super
      val = Oj.load(val) if val
      val
    end

    delegate :service, to: :service_plan

    delegate :service_broker, to: :service_plan

    delegate :route_service?, to: :service

    delegate :shareable?, to: :service

    delegate :volume_service?, to: :service

    def logger
      @logger ||= Steno.logger('cc.models.service_instance')
    end

    delegate :bindable?, to: :service_plan

    def merged_tags
      (service.tags + tags).uniq
    end

    def update_service_instance(attributes_to_update)
      update_attributes(attributes_to_update)
    end

    def save_and_update_operation(attributes_to_update)
      ManagedServiceInstance.db.transaction do
        lock!

        instance_attrs, operation_attrs = extract_operation_attrs(attributes_to_update)
        update_attributes(instance_attrs)

        update_last_operation(operation_attrs) if operation_attrs
      end
    end

    def extract_operation_attrs(attributes_to_update)
      operation_attrs = attributes_to_update.delete(:last_operation)
      [attributes_to_update, operation_attrs]
    end

    def update_last_operation(operation_attrs)
      last_operation.update_attributes operation_attrs
    end
  end
end
