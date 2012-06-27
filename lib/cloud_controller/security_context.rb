# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  module SecurityContext
    def self.current_user=(user)
      Thread.current[:vcap_user] = user
    end

    def self.current_user
      Thread.current[:vcap_user]
    end

    def self.current_user_is_admin?
      return current_user && current_user.admin?
    end
  end
end
