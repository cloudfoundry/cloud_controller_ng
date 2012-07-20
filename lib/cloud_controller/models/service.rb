# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Service < Sequel::Model
    one_to_many :service_plans
    one_to_many :service_instances
    many_to_many :service_bindings, :join_table => :service_instances, :right_key => :id, :right_primary_key => :service_instance_id

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
