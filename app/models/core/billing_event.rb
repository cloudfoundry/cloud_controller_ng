# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class BillingEvent < Sequel::Model
    plugin :single_table_inheritance, :kind,
           :key_chooser => proc { |instance| instance.model },
           :model_map => proc { |instance| instance.to_s.gsub("::Models::", "::") }

    def validate
      validates_presence :timestamp
      validates_presence :organization_guid
      validates_presence :organization_name
    end
  end
end
