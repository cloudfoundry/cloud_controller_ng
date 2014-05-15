module VCAP::CloudController
  class ServicePlan < Sequel::Model
    many_to_one       :service
    one_to_many       :service_instances
    one_to_many       :service_plan_visibilities

    add_association_dependencies service_plan_visibilities: :destroy

    default_order_by  :name

    export_attributes :name, :free, :description, :service_guid, :extra, :unique_id, :public, :active

    import_attributes :name, :free, :description, :service_guid, :extra, :unique_id, :public

    strip_attributes  :name

    delegate :client, to: :service

    alias_method :active?, :active

    def validate
      validates_presence :name,                message: 'is required'
      validates_presence :description,         message: 'is required'
      validates_presence :free,                message: 'is required'
      validates_presence :service,             message: 'is required'
      validates_presence :unique_id,           message: 'is required'
      validates_unique   [:service_id, :name], message: Sequel.lit('Plan names must be unique within a service')
      validates_unique   :unique_id,           message: Sequel.lit('Plan ids must be unique')
    end

    def_dataset_method(:organization_visible) do |organization|
      filter(Sequel.|(
        {public: true},
        {id: ServicePlanVisibility.visible_private_plan_ids_for_organization(organization)}
      ).&(active: true))
    end

    def self.user_visibility_filter(user)
      Sequel.
        or(public: true, id: ServicePlanVisibility.visible_private_plan_ids_for_user(user)).
        &(active: true)
    end

    def bindable?
      service.bindable?
    end

    # The "unique_id" should really be called broker_provided_id because it's the id assigned by the broker
    def broker_provided_id
      unique_id
    end

    private

    def before_validation
      generate_unique_id if new?
      super
    end

    def generate_unique_id
      self.unique_id ||= SecureRandom.uuid
    end
  end
end
