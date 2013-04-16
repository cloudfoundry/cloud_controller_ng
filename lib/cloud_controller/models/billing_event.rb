# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class BillingEvent < Sequel::Model
    plugin :single_table_inheritance, :kind

    def validate
      validates_presence :timestamp
      validates_presence :organization_guid
      validates_presence :organization_name
    end
    
    def timestamp
      self.event_timestamp
    end
    
    def timestamp=(value)
      self.event_timestamp = value
    end

    def self.user_visibility_filter(user)
      # don't allow anyone to enumerate other than the admin
      user_visibility_filter_with_admin_override(:id => nil)
    end
  end
end
