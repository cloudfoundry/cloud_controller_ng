require 'repositories/service_usage_event_repository'

module VCAP::CloudController
  class ServiceInstance < Sequel::Model
    class InvalidServiceBinding < StandardError; end

    ROUTE_SERVICE_WARNING = 'Support for route services is disabled. This service instance cannot be bound to a route.'.freeze
    VOLUME_SERVICE_WARNING = 'Support for volume services is disabled. This service instance cannot be bound to an app.'.freeze

    plugin :serialization
    plugin :single_table_inheritance, :is_gateway_service,
           model_map: lambda { |is_gateway_service|
             if is_gateway_service
               VCAP::CloudController::ManagedServiceInstance
             else
               VCAP::CloudController::UserProvidedServiceInstance
             end
           },
           key_map: lambda { |klazz|
             klazz == VCAP::CloudController::ManagedServiceInstance
           }

    one_to_one :service_instance_operation

    one_to_many :service_bindings, before_add: :validate_service_binding
    one_to_many :service_keys
    many_to_many :routes, join_table: :route_bindings

    many_to_one :space, after_set: :validate_space
    many_to_one :service_plan_sti_eager_load,
                class: 'VCAP::CloudController::ServicePlan',
                dataset: -> { raise 'Must be used for eager loading' },
                eager_loader_key: nil, # set up id_map ourselves
                eager_loader: proc { |eo|
                  id_map = {}
                  eo[:rows].each do |service_instance|
                    service_instance.associations[:service_plan] = nil
                    id_map[service_instance.service_plan_id] ||= []
                    id_map[service_instance.service_plan_id] << service_instance
                  end

                  ds = ServicePlan.where(id: id_map.keys)
                  ds = ds.eager(eo[:associations]) if eo[:associations]
                  ds = eo[:eager_block].call(ds) if eo[:eager_block]

                  ds.all do |service_plan|
                    id_map[service_plan.id].each { |si| si.associations[:service_plan] = service_plan }
                  end
                }

    delegate :organization, to: :space

    encrypt :credentials, salt: :salt

    def self.user_visibility_filter(user)
      Sequel.or([
        [:space, managed_organizations_spaces_dataset(user.managed_organizations_dataset)],
        [:space, user.spaces_dataset],
        [:space, user.audited_spaces_dataset],
        [:space, user.managed_spaces_dataset],
      ])
    end

    def type
      self.class.name.demodulize.underscore
    end

    def user_provided_instance?
      self.type == UserProvidedServiceInstance.name.demodulize.underscore
    end

    def managed_instance?
      !user_provided_instance?
    end

    def validate
      validates_presence :name
      validates_presence :space
      validates_unique [:space_id, :name], where: (proc do |_, obj, arr|
                                                     vals = arr.map { |x| obj.send(x) }
                                                     next if vals.any?(&:nil?)
                                                     ServiceInstance.where(arr.zip(vals))
                                                   end)
      validates_max_length 50, :name
    end

    # Make sure all derived classes use the base access class
    def self.source_class
      ServiceInstance
    end

    def bindable?
      true
    end

    def as_summary_json
      {
        'guid' => guid,
        'name' => name,
        'bound_app_count' => service_bindings_dataset.count,
      }
    end

    def to_hash(opts={})
      if !SecurityContext.admin? && !SecurityContext.admin_read_only? && !space.has_developer?(SecurityContext.current_user)
        opts[:redact] = ['credentials']
      end
      hash = super(opts)
      hash
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

    def in_suspended_org?
      space.in_suspended_org?
    end

    def after_create
      super
      service_instance_usage_event_repository.created_event_from_service_instance(self)
    end

    def after_destroy
      super
      service_instance_usage_event_repository.deleted_event_from_service_instance(self)
    end

    def after_update
      super
      update_service_bindings
      if @columns_updated.key?(:service_plan_id) || @columns_updated.key?(:name)
        service_instance_usage_event_repository.updated_event_from_service_instance(self)
      end
    end

    def last_operation
      nil
    end

    def operation_in_progress?
      false
    end

    def route_service?
      false
    end

    def volume_service?
      false
    end

    def self.managed_organizations_spaces_dataset(managed_organizations_dataset)
      VCAP::CloudController::Space.dataset.filter({ organization_id: managed_organizations_dataset.select(:organization_id) })
    end

    private

    def validate_service_binding(service_binding)
      if service_binding && service_binding.app.space != space
        raise InvalidServiceBinding.new(service_binding.id)
      end
    end

    def validate_space(space)
      service_bindings.each { |binding| validate_service_binding(binding) }
    end

    def service_instance_usage_event_repository
      @repository ||= Repositories::ServiceUsageEventRepository.new
    end

    def update_service_bindings
      if @columns_updated.key?(:syslog_drain_url)
        service_bindings_dataset.update(syslog_drain_url: syslog_drain_url)
      end
    end
  end
end
