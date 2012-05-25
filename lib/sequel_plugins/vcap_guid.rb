# Copyright (c) 2009-2012 VMware, Inc.

require "securerandom"

module Sequel::Plugins::VcapGuid
  module InstanceMethods
    def before_create
      if self.columns.include?(:guid) && self.send(:guid).nil?
        self.send(:guid=, SecureRandom.uuid)
      end
      super
    end
  end
end
