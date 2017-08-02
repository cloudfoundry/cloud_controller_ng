module VCAP::CloudController
  class ServicePlan < Sequel::Model
    many_to_one :service
    one_to_many :service_instances
    one_to_many :service_plan_visibilities

    add_association_dependencies service_plan_visibilities: :destroy

    export_attributes :name, :free, :description, :service_guid, :extra, :unique_id, :public, :bindable, :active, :create_instance_schema, :update_instance_schema

    export_attributes_from_methods bindable: :bindable?

    import_attributes :name, :free, :description, :service_guid, :extra, :unique_id, :public, :bindable, :create_instance_schema, :update_instance_schema

    strip_attributes :name

    delegate :client, to: :service

    alias_method :active?, :active

    alias_method :broker_provided_id, :unique_id

    def validate
      validates_presence :name,                message: 'is required'
      validates_presence :description,         message: 'is required'
      validates_presence :free,                message: 'is required'
      validates_presence :service,             message: 'is required'
      validates_presence :unique_id,           message: 'is required'
      validates_unique [:service_id, :name],   message: Sequel.lit("Plan names must be unique within a service. Service #{service.try(:label)} already has a plan named #{name}")
      validates_unique :unique_id,             message: Sequel.lit('Plan ids must be unique')
      validate_private_broker_plan_not_public
    end

    def_dataset_method(:organization_visible) do |organization|
      filter(Sequel.|(
        { public: true },
        { id: ServicePlanVisibility.visible_private_plan_ids_for_organization(organization) }
      ).&(active: true))
    end

    def_dataset_method(:space_visible) do |space|
      filter(Sequel.|(
        { public: true },
        { id: ServicePlanVisibility.visible_private_plan_ids_for_organization(space.organization) },
        { id: ServicePlan.plan_ids_from_private_brokers_by_space(space) }
      ).&(active: true))
    end

    def self.user_visible(user, admin_override=false, op=nil)
      dataset.filter(user_visibility(user, admin_override, op))
    end

    def self.user_visibility(user, admin_override, op=nil)
      if !admin_override && user
        op == :read ? user_visibility_show_filter(user) : user_visibility_list_filter(user)
      else
        super(user, admin_override)
      end
    end

    def self.user_visibility_for_read(user, admin_override)
      user_visibility(user, admin_override, :read)
    end

    def self.user_visibility_list_filter(user)
      included_ids = ServicePlanVisibility.visible_private_plan_ids_for_user(user).
                     concat(plan_ids_from_private_brokers(user))

      Sequel.or({ public: true, id: included_ids }).&(active: true)
    end

    def self.user_visibility_show_filter(user)
      list_filter = self.user_visibility_list_filter(user)
      Sequel.|(list_filter, { id: plan_ids_for_visible_service_instances(user) })
    end

    def self.plan_ids_from_private_brokers(user)
      plan_ids_from_brokers(user.membership_spaces.join(:service_brokers, space_id: :id))
    end

    def self.plan_ids_from_private_brokers_by_space(space)
      plan_ids_from_brokers(ServiceBroker.where(space_id: space.id))
    end

    def self.plan_ids_from_brokers(broker_ds)
      broker_ds.join(:services, service_broker_id: :id).
        join(:service_plans, service_id: :id).
        map(&:id).flatten.uniq
    end

    def self.plan_ids_for_visible_service_instances(user)
      plan_ids = []
      user.spaces.each do |space|
        space.service_instances.select(&:managed_instance?).each do |service_instance|
          plan_ids << service_instance.service_plan.id
        end
      end
      plan_ids.uniq
    end

    def bindable?
      return bindable unless bindable.nil?
      service.bindable?
    end

    def service_broker
      service.service_broker if service
    end

    def broker_private?
      service_broker.private? if service_broker
    end

    private

    def before_validation
      generate_unique_id if new?
      self.public = !broker_private? if self.public.nil?
      super
    end

    def generate_unique_id
      self.unique_id ||= SecureRandom.uuid
    end

    def validate_private_broker_plan_not_public
      if broker_private? && self.public
        errors.add(:public, 'may not be true for plans belonging to private service brokers')
      end
    end
  end
end
