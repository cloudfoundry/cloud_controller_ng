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
      self.guid = SecureRandom.uuid if columns.include?(:guid) && guid.nil? && !self.class.no_auto_guid_flag
      super
    end
  end
end
