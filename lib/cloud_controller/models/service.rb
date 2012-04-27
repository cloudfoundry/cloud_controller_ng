# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Service < Sequel::Model
    one_to_many :service_plans

    default_order_by  :label

    export_attributes :id, :label, :provider, :url, :type, :description,
                      :version, :info_url, :service_plan_ids,
                      :created_at, :updated_at

    import_attributes :label, :provider, :url, :type, :description,
                      :version, :info_url

    strip_attributes  :label, :provider

    def validate
      validates_presence :label
      validates_presence :provider
      validates_presence :url
      validates_presence :type
      validates_presence :description
      validates_presence :version
      validates_url      :url
      validates_url      :info_url
      validates_unique   [:label, :provider]
    end
  end
end
