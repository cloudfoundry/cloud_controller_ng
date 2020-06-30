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
    plugin :columns_updated

    serialize_attributes :json, :tags

    one_to_one :service_instance_operation

    one_to_many :service_bindings, before_add: :validate_service_binding, key: :service_instance_guid, primary_key: :guid
    one_to_many :service_keys

    one_to_many :labels, class: 'VCAP::CloudController::ServiceInstanceLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::ServiceInstanceAnnotationModel', key: :resource_guid, primary_key: :guid
    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    many_to_many :shared_spaces,
          left_key:          :service_instance_guid,
          left_primary_key:  :guid,
          right_key:         :target_space_guid,
          right_primary_key: :guid,
          join_table:        :service_instance_shares,
          class: VCAP::CloudController::Space

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

    set_field_as_encrypted :credentials

    def self.user_visibility_filter(user)
      visible_spaces = user.spaces_dataset.
                       union(user.audited_spaces_dataset).
                       union(user.managed_spaces_dataset).
                       union(managed_organizations_spaces_dataset(user.managed_organizations_dataset)).all.uniq

      Sequel.or([
        [:space, visible_spaces],
        [:shared_spaces, visible_spaces]
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

    def name_clashes
      proc do |_, instance|
        next if instance.space_id.nil? || instance.name.nil?

        clashes_with_shared_instance_names =
          ServiceInstance.select_all(ServiceInstance.table_name).
          join(:service_instance_shares, service_instance_guid: :guid, target_space_guid: instance.space_guid).
          where(name: instance.name)

        clashes_with_instance_names =
          ServiceInstance.select_all(ServiceInstance.table_name).
          where(space_id: instance.space_id, name: instance.name)

        clashes_with_shared_instance_names.union(clashes_with_instance_names)
      end
    end

    def validate
      validates_presence :name
      validates_presence :space
      validates_unique :name, where: name_clashes
      validates_max_length 50, :name
      validates_max_length 10_000, :syslog_drain_url, allow_nil: true
      validate_tags_length
    end

    # Make sure all derived classes use the base access class
    def self.source_class
      ServiceInstance
    end

    def tags
      super || []
    end

    def bindable?
      true
    end

    def as_summary_json
      {
        'guid' => guid,
        'name' => name,
        'bound_app_count' => service_bindings_dataset.count,
        'type' => type,
      }
    end

    def to_hash(opts={})
      access_context = VCAP::CloudController::Security::AccessContext.new
      if access_context.cannot?(:read_env, self)
        opts[:redact] = ['credentials']
      end
      hash = super(opts)
      hash
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

    def in_suspended_org?
      space&.in_suspended_org?
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

    def shareable?
      false
    end

    def volume_service?
      false
    end

    def shared?
      shared_spaces.any?
    end

    def has_bindings?
      service_bindings.present?
    end

    def has_keys?
      service_keys.present?
    end

    def has_routes?
      routes.present?
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

    def validate_tags_length
      if tags.join('').length > 2048
        @errors[:tags] = [:too_long]
      end
    end

    def service_instance_usage_event_repository
      @service_instance_usage_event_repository ||= Repositories::ServiceUsageEventRepository.new
    end

    def update_service_bindings
      if columns_updated.key?(:syslog_drain_url)
        service_bindings_dataset.update(syslog_drain_url: syslog_drain_url)
      end
    end
  end
end
