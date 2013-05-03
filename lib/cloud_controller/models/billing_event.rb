# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class BillingEvent < Sequel::Model
    plugin :single_table_inheritance, :kind

    vcap_column_alias :timestamp, :event_timestamp

    def validate
      validates_presence :timestamp
      validates_presence :organization_guid
      validates_presence :organization_name
    end
    
    def self.user_visibility_filter(user)
      # don't allow anyone to enumerate other than the admin
      user_visibility_filter_with_admin_override(:id => nil)
    end
  end
end
