require 'securerandom'

module Sequel::Plugins::VcapGuid
  module ClassMethods
    def no_auto_guid
      self.no_auto_guid_flag = true
    end

    attr_accessor :no_auto_guid_flag
  end

  module InstanceMethods
    def before_create
      if self.columns.include?(:guid) && self.guid.nil? && !self.class.no_auto_guid_flag
        self.guid = SecureRandom.uuid
      end
      super
    end
  end
end
