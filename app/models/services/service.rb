# Copyright (c) 2009-2012 VMware, Inc.

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
                      :unique_id, :extra, :tags, :requires, :documentation_url

    import_attributes :label, :provider, :url, :description, :long_description,
                      :version, :info_url, :active, :bindable,
                      :unique_id, :extra, :tags, :requires, :documentation_url

    strip_attributes  :label, :provider

    def validate
      validates_presence :label
      validates_presence :description
      validates_presence :bindable
      validates_url      :url
      validates_url      :info_url
      validates_unique   [:label, :provider]
    end

    serialize_attributes :json, :tags, :requires

    alias_method :bindable?, :bindable

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
      if v2?
        service_broker.client
      else
        @v1_client ||= ServiceBroker::V1::Client.new(
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
  end
end
