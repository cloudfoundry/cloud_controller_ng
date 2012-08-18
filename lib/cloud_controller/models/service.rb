# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Service < Sequel::Model
    one_to_many :service_plans
    many_to_many :service_instances, :join_table => :service_plans, :right_primary_key => :service_plan_id, :right_key => :id
    many_to_many :service_bindings, :dataset => lambda { ServiceBinding.filter(:service_instance => service_instances) }
    one_to_one  :service_auth_token, :key => [:label, :provider], :primary_key => [:label, :provider]

    add_association_dependencies :service_plans => :destroy

    default_order_by  :label

    export_attributes :label, :provider, :url, :description,
                      :version, :info_url

    import_attributes :label, :provider, :url, :description,
                      :version, :info_url

    strip_attributes  :label, :provider

    def validate
      validates_presence :label
      validates_presence :provider
      validates_presence :url
      validates_presence :description
      validates_presence :version
      validates_url      :url
      validates_url      :info_url
      validates_unique   [:label, :provider]
    end
  end
end
