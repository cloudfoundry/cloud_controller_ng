module VCAP::CloudController
  class ServicePlan < Sequel::Model
    many_to_one :service
    one_to_many :service_instances

    one_to_many :service_plan_visibilities, clearer: (lambda do
      service_plan_visibilities_dataset.delete
    end)

    add_association_dependencies service_plan_visibilities: :destroy

    one_to_many :labels, class: 'VCAP::CloudController::ServicePlanLabelModel', key: :resource_guid, primary_key: :guid
    add_association_dependencies labels: :destroy

    one_to_many :annotations, class: 'VCAP::CloudController::ServicePlanAnnotationModel', key: :resource_guid, primary_key: :guid
    add_association_dependencies annotations: :destroy

    plugin :serialization

    export_attributes :name,
                      :free,
                      :description,
                      :service_guid,
                      :extra,
                      :unique_id,
                      :public,
                      :bindable,
                      :plan_updateable,
                      :active,
                      :maximum_polling_duration,
                      :maintenance_info,
                      :create_instance_schema,
                      :update_instance_schema,
                      :create_binding_schema

    export_attributes_from_methods bindable: :bindable?

    import_attributes :name,
                      :free,
                      :description,
                      :service_guid,
                      :extra,
                      :unique_id,
                      :public,
                      :bindable,
                      :plan_updateable,
                      :maximum_polling_duration,
                      :maintenance_info,
                      :create_instance_schema,
                      :update_instance_schema,
                      :create_binding_schema

    serialize_attributes :json, :maintenance_info

    strip_attributes :name

    # When selecting a UNION of multiple sub-queries, MySQL does not maintain the original type - i.e. tinyint(1) - and
    # thus Sequel does not convert the value to a boolean.
    # See https://bugs.mysql.com/bug.php?id=30886
    def free?
      ActiveModel::Type::Boolean.new.cast(free)
    end

    def public?
      ActiveModel::Type::Boolean.new.cast(public)
    end

    def active?
      ActiveModel::Type::Boolean.new.cast(active)
    end

    alias_method :broker_provided_id, :unique_id

    def validate
      validates_presence :name,                message: 'is required'
      validates_presence :description,         message: 'is required'
      validates_presence :free,                message: 'is required'
      validates_presence :service,             message: 'is required'
      validates_presence :unique_id,           message: 'is required'
      validates_unique [:service_id, :name],   message: Sequel.lit("Plan names must be unique within a service. Service #{service.try(:label)} already has a plan named #{name}")
      validate_private_broker_plan_not_public
    end

    dataset_module do
      def organization_visible(organization)
        filter(Sequel.|(
          { public: true },
          { id: ServicePlanVisibility.visible_private_plan_ids_for_organization(organization.id) }
        ).&(active: true))
      end

      def space_visible(space)
        filter(Sequel.|(
          { public: true },
          { id: ServicePlanVisibility.visible_private_plan_ids_for_organization(space.organization_id) },
          { id: ServicePlan.plan_ids_from_private_brokers_by_space(space) }
        ).&(active: true))
      end
    end

    def self.user_visible(user, admin_override=false, operation=nil)
      dataset.filter(user_visibility(user, admin_override, operation))
    end

    def self.user_visibility(user, admin_override, operation=nil)
      if !admin_override && user
        operation == :read ? user_visibility_show_filter(user) : user_visibility_list_filter(user)
      else
        super(user, admin_override)
      end
    end

    def self.user_visibility_for_read(user, admin_override)
      user_visibility(user, admin_override, :read)
    end

    def self.user_visibility_list_filter(user)
      Sequel.or([
        [:public, true],
        [:service_plans__id, ServicePlanVisibility.visible_private_plan_ids_for_user(user)],
        [:service_plans__id, plan_ids_from_private_brokers(user)]
      ]).&(service_plans__active: true)
    end

    def self.user_visibility_show_filter(user)
      list_filter = self.user_visibility_list_filter(user)
      Sequel.|(list_filter, { id: plan_ids_for_visible_service_instances(user) })
    end

    def self.plan_ids_from_private_brokers(user)
      plan_ids_for_space(user.membership_space_ids)
    end

    def self.plan_ids_from_private_brokers_by_space(space)
      plan_ids_for_space(space.id)
    end

    def self.plan_ids_for_space(space_id)
      ServiceBroker.where(space_id: space_id).
        join(:services, service_broker_id: :id).
        join(:service_plans, service_id: :id).
        select(:service_plans__id).distinct
    end

    def self.plan_ids_for_visible_service_instances(user)
      dataset.select(&:managed_instance?).
        join(:service_instances, service_plan_id: :id, service_instances__space_id: user.membership_spaces.select(:id)).
        select(:service_plans__id).distinct
    end

    def bindable?
      return bindable unless bindable.nil?

      service.bindable?
    end

    def plan_updateable?
      return plan_updateable unless plan_updateable.nil?

      !!service.plan_updateable
    end

    def service_broker
      service.service_broker if service
    end

    def broker_space_scoped?
      service_broker.space_scoped? if service_broker
    end

    def visible_in_space?(space)
      visible_plans = ServicePlan.space_visible(space)
      visible_plans.include?(self)
    end

    def visibility_type
      return ServicePlanVisibilityTypes::PUBLIC if public?

      return ServicePlanVisibilityTypes::SPACE if broker_space_scoped?

      return ServicePlanVisibilityTypes::ORGANIZATION unless service_plan_visibilities_dataset.empty?

      return ServicePlanVisibilityTypes::ADMIN
    end

    private

    def before_validation
      generate_unique_id if new?
      self.public = !broker_space_scoped? if self.public.nil?
      super
    end

    def generate_unique_id
      self.unique_id ||= SecureRandom.uuid
    end

    def validate_private_broker_plan_not_public
      if broker_space_scoped? && self.public?
        errors.add(:public, 'may not be true for plans belonging to private service brokers')
      end
    end
  end

  class ServicePlanVisibilityTypes
    PUBLIC = 'public'.freeze
    ADMIN = 'admin'.freeze
    SPACE = 'space'.freeze
    ORGANIZATION = 'organization'.freeze
  end
end
