require 'vcap/request'

module VCAP::CloudController
  class ManagedServiceInstance < ServiceInstance
    IN_PROGRESS_STRING = 'in progress'.freeze

    many_to_one :service_plan

    export_attributes :name, :credentials, :service_plan_guid,
      :space_guid, :gateway_data, :dashboard_url, :type, :last_operation,
      :tags

    import_attributes :name, :service_plan_guid,
      :space_guid, :gateway_data

    strip_attributes :name

    plugin :after_initialize

    serialize_attributes :json, :tags

    delegate :client, to: :service_plan

    add_association_dependencies service_instance_operation: :destroy

    def validation_policies
      if space
        [
          MaxServiceInstancePolicy.new(self, organization.managed_service_instances.count, organization.quota_definition, :service_instance_quota_exceeded),
          MaxServiceInstancePolicy.new(self, space.managed_service_instances.count, space.space_quota_definition, :service_instance_space_quota_exceeded),
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
      validate_tags_length
    end

    def last_operation
      service_instance_operation
    end

    def after_initialize
      super
      self.guid ||= SecureRandom.uuid
    end

    def as_summary_json
      super.merge(
        'last_operation' => last_operation.try(:to_hash),
        'dashboard_url' => dashboard_url,
        'service_plan' => {
          'guid' => service_plan.guid,
          'name' => service_plan.name,
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
      return super(opts) if service_instance_operation.nil?

      last_operation_hash = service_instance_operation.to_hash({})
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

    def volume_service?
      service.volume_service?
    end

    def logger
      @logger ||= Steno.logger('cc.models.service_instance')
    end

    def bindable?
      service_plan.bindable?
    end

    def tags
      super || []
    end

    def dashboard_url
      admin_context = VCAP::CloudController::SecurityContext.admin? || VCAP::CloudController::SecurityContext.admin_read_only?
      unless admin_context || space.has_developer?(VCAP::CloudController::SecurityContext.current_user)
        return ''
      end
      super
    end

    def merged_tags
      (service.tags + tags).uniq
    end

    def terminal_state?
      ['succeeded', 'failed'].include? last_operation.state
    end

    def operation_in_progress?
      if last_operation && last_operation.state == IN_PROGRESS_STRING
        return true
      end
      false
    end

    def save_with_new_operation(instance_attributes, last_operation)
      update_attributes(instance_attributes)

      if self.last_operation
        self.last_operation.destroy
      end

      self.service_instance_operation = ServiceInstanceOperation.new(last_operation)
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

    private

    def update_attributes(instance_attrs)
      set_all(instance_attrs)
      save_changes
    end

    def validate_tags_length
      if tags.join('').length > 2048
        @errors[:tags] = [:too_long]
      end
    end
  end
end
