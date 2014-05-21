module VCAP::CloudController
  class Service < Sequel::Model
    plugin :serialization

    many_to_one :service_broker
    one_to_many :service_plans
    one_to_one  :service_auth_token, :key => [:label, :provider], :primary_key => [:label, :provider]

    add_association_dependencies :service_plans => :destroy

    default_order_by  :label

    export_attributes :label, :provider, :url, :description, :long_description,
                      :version, :info_url, :active, :bindable,
                      :unique_id, :extra, :tags, :requires, :documentation_url, :service_broker_guid

    import_attributes :label, :provider, :url, :description, :long_description,
                      :version, :info_url, :active, :bindable,
                      :unique_id, :extra, :tags, :requires, :documentation_url

    strip_attributes  :label, :provider

    def validate
      validates_presence :label,              message:  Sequel.lit('Service name is required')
      validates_presence :description,        message: 'is required'
      validates_presence :bindable,           message: 'is required'
      validates_url      :url,                message: 'must be a valid url'
      validates_url      :info_url,           message: 'must be a valid url'
      validates_unique   :unique_id,          message: Sequel.lit('Service ids must be unique')

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

    def self.organization_visible(organization)
      service_ids = ServicePlan.
          organization_visible(organization).
          inject([]) { |service_ids,service_plan| service_ids << service_plan.service_id }
      dataset.filter(id: service_ids)
    end

    def self.user_visibility_filter(current_user)
      plans_I_can_see = ServicePlan.user_visible(current_user)
      {id: plans_I_can_see.map(&:service_id).uniq}
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
        raise VCAP::Errors::ApiError.new_from_details("MissingServiceAuthToken", label) if service_auth_token.nil?

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

    def purge
      db.transaction(savepoint: true) do
        self.update(purging: true)
        service_plans.each do |plan|
          plan.service_instances_dataset.destroy
        end
        self.destroy
      end
    end

    def service_broker_guid
      service_broker ? service_broker.guid : nil
    end
  end
end
