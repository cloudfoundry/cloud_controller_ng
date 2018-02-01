module VCAP::CloudController
  class Service < Sequel::Model
    plugin :serialization

    many_to_one :service_broker
    one_to_many :service_plans

    add_association_dependencies service_plans: :destroy

    export_attributes :label, :provider, :url, :description, :long_description,
                      :version, :info_url, :active, :bindable,
                      :unique_id, :extra, :tags, :requires, :documentation_url,
                      :service_broker_guid, :plan_updateable, :bindings_retrievable, :instances_retrievable

    import_attributes :label, :description, :long_description, :info_url,
                      :active, :bindable, :unique_id, :extra,
                      :tags, :requires, :documentation_url, :plan_updateable,
                      :bindings_retrievable, :instances_retrievable

    strip_attributes :label

    class << self
      def public_visible
        public_active_plans = ServicePlan.where(active: true, public: true).all
        service_ids = public_active_plans.map(&:service_id).uniq
        dataset.filter(id: service_ids)
      end

      def user_visibility_filter(current_user, op=nil)
        visible_plans = ServicePlan.user_visible(current_user, op)
        ids_from_plans = visible_plans.map(&:service_id).uniq

        { id: ids_from_plans }
      end

      def user_visibility_for_read(current_user, _admin_override)
        user_visibility_filter(current_user, :read)
      end

      def unauthenticated_visibility_filter
        { id: self.public_visible.map(&:id) }
      end

      def space_or_org_visible_for_user(space, user)
        organization_visible(space.organization).union(space_visible(space, user), alias: :services)
      end

      def organization_visible(organization)
        service_ids = ServicePlan.
                      organization_visible(organization).
                      inject([]) { |ids_so_far, service_plan| ids_so_far << service_plan.service_id }
        dataset.filter(id: service_ids)
      end

      private

      def space_visible(space, user)
        if space.has_member?(user) || can_read_globally?(user)
          private_brokers_for_space = ServiceBroker.filter(space_id: space.id)
          dataset.filter(service_broker: private_brokers_for_space)
        else
          dataset.filter(id: nil)
        end
      end

      def can_read_globally?(user)
        VCAP::CloudController::Permissions.new(user).can_read_globally?
      end
    end

    def validate
      validates_presence :label, message: Sequel.lit('Service name is required')
      validates_presence :description, message: 'is required'
      validates_presence :bindable, message: 'is required'
      validates_url :info_url, message: 'must be a valid url'
      validates_unique :unique_id, message: Sequel.lit('Service ids must be unique')
      validates_max_length 2048, :tag_contents, message: Sequel.lit("Service tags for service #{label} must be 2048 characters or less.")

      validates_unique :label, message: Sequel.lit('Service name must be unique') do |ds|
        ds.exclude(service_broker_id: nil)
      end
    end

    serialize_attributes :json, :tags, :requires

    alias_method :bindable?, :bindable
    alias_method :active?, :active

    def tags
      super || []
    end

    def tag_contents
      tags.join
    end

    def requires
      super || []
    end

    def client
      if purging
        VCAP::Services::ServiceBrokers::NullClient.new
      else
        service_broker.client
      end
    end

    # The "unique_id" should really be called broker_provided_id because it's the id assigned by the broker
    def broker_provided_id
      unique_id
    end

    def purge(event_repository)
      db.transaction do
        self.update(purging: true)
        service_plans.each do |plan|
          plan.service_instances_dataset.each do |instance|
            ServiceInstancePurger.new(event_repository).purge(instance)
          end
        end
        self.destroy
      end
    end

    def service_broker_guid
      service_broker ? service_broker.guid : nil
    end

    def route_service?
      requires.include?('route_forwarding')
    end

    def shareable?
      return false if extra.nil?
      metadata = JSON.parse(extra)
      metadata && metadata['shareable']
    rescue JSON::ParserError
      return false
    end

    def volume_service?
      requires.include?('volume_mount')
    end

    def deleted_field
      nil
    end

    alias_method :provider, :deleted_field
    alias_method :url, :deleted_field
    alias_method :version, :deleted_field
  end
end
