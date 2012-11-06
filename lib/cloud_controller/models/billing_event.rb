# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class BillingEvent < Sequel::Model
    plugin :single_table_inheritance, :kind

    def validate
      validates_presence :timestamp
      validates_presence :organization_guid
      validates_presence :organization_name
    end

    def self.user_visibility_filter(user)
      # don't allow anyone to enumerate other than the admin
      user_visibility_filter_with_admin_override(:id => nil)
    end

    alias :organization_id :organization_guid
    alias :space_id :space_guid
    alias :app_id :app_guid
    alias :service_id :service_guid
    alias :service_plan_id :service_plan_guid
    alias :service_instance_id :service_instance_guid
  end
end
