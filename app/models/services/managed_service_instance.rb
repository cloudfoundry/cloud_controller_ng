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

    serialize_attributes :json, :maintenance_info

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
            'version' => service.version,
          }
        }
      )
    end

    def to_hash(opts={})
      return super(opts) if last_operation.nil?

      last_operation_hash = last_operation.to_hash({})
      super(opts).merge!('last_operation' => last_operation_hash)
    end

    def gateway_data=(val)
      str = MultiJson.dump(val)
      super(str)
    end

    def gateway_data
      val = super
      val = MultiJson.load(val) if val
      val
    end

    def requester
      VCAP::Services::Api::SynchronousHttpRequest
    end

    def service
      service_plan.service
    end

    def service_broker
      service_plan.service_broker
    end

    def route_service?
      service.route_service?
    end

    def shareable?
      service.shareable?
    end

    def volume_service?
      service.volume_service?
    end

    def logger
      @logger ||= Steno.logger('cc.models.service_instance')
    end

    def bindable?
      service_plan.bindable?
    end

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

        if operation_attrs
          update_last_operation(operation_attrs)
        end
      end
    end

    def extract_operation_attrs(attributes_to_update)
      operation_attrs = attributes_to_update.delete(:last_operation)
      [attributes_to_update, operation_attrs]
    end

    def update_last_operation(operation_attrs)
      self.last_operation.update_attributes operation_attrs
    end
  end
end
