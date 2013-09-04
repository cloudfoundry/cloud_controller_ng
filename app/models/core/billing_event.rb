# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class BillingEvent < Sequel::Model
    plugin :single_table_inheritance, :kind

    def validate
      validates_presence :timestamp
      validates_presence :organization_guid
      validates_presence :organization_name
    end
  end
end
