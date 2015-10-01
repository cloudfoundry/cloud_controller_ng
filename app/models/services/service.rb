module VCAP::CloudController
  class Service < Sequel::Model
    plugin :serialization

    many_to_one :service_broker
    one_to_many :service_plans
    one_to_one :service_auth_token, key: [:label, :provider], primary_key: [:label, :provider]

    add_association_dependencies service_plans: :destroy

    export_attributes :label, :provider, :url, :description, :long_description,
                      :version, :info_url, :active, :bindable,
                      :unique_id, :extra, :tags, :requires, :documentation_url, :service_broker_guid, :plan_updateable

    import_attributes :label, :provider, :url, :description, :long_description,
                      :version, :info_url, :active, :bindable,
                      :unique_id, :extra, :tags, :requires, :documentation_url, :plan_updateable

    strip_attributes :label, :provider

    def validate
      validates_presence :label,              message:  Sequel.lit('Service name is required')
      validates_presence :description,        message: 'is required'
      validates_presence :bindable,           message: 'is required'
      validates_url :url,                message: 'must be a valid url'
      validates_url :info_url,           message: 'must be a valid url'
      validates_unique :unique_id,          message: Sequel.lit('Service ids must be unique')

      if v2?
        validates_unique :label, message: Sequel.lit('Service name must be unique') do |ds|
          ds.exclude(service_broker_id: nil)
        end
      else
        validates_unique [:label, :provider], message: 'is taken'
      end
    end

    serialize_attributes :json, :tags, :requires

    alias_method :bindable?, :bindable
    alias_method :active?, :active

    class << self
      def public_visible
        public_active_plans = ServicePlan.where(active: true, public: true).all
        service_ids = public_active_plans.map(&:service_id).uniq
        dataset.filter(id: service_ids)
      end

      def user_visibility_filter(current_user)
        visible_plans = ServicePlan.user_visible(current_user)
        ids_from_plans = visible_plans.map(&:service_id).uniq

        { id: ids_from_plans }
      end

      def unauthenticated_visibility_filter
        { id: self.public_visible.map(&:id) }
      end

      def space_or_org_visible_for_user(space, user)
        organization_visible(space.organization).union space_visible(space, user)
      end

      def organization_visible(organization)
        service_ids = ServicePlan.
          organization_visible(organization).
          inject([]) { |ids_so_far, service_plan| ids_so_far << service_plan.service_id }
        dataset.filter(id: service_ids)
      end

      private

      def space_visible(space, user)
        if space.has_member? user
          private_brokers_for_space = ServiceBroker.filter(space_id: space.id)
          dataset.filter(service_broker: (private_brokers_for_space))
        else
          dataset.filter(id: nil)
        end
      end
    end

    def provider
      provider = self[:provider]
      provider.blank? ? nil : provider
    end

    def tags
      super || []
    end

    def requires
      super || []
    end

    def v2?
      !service_broker.nil?
    end

    def client
      if purging
        VCAP::Services::ServiceBrokers::NullClient.new
      elsif v2?
        service_broker.client
      else
        raise VCAP::Errors::ApiError.new_from_details('MissingServiceAuthToken', label) if service_auth_token.nil?

        @v1_client ||= VCAP::Services::ServiceBrokers::V1::Client.new(
          url: url,
          auth_token: service_auth_token.token,
          timeout: timeout
        )
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
  end
end
