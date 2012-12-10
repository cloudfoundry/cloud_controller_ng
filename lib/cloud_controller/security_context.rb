# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  module SecurityContext
    def self.clear
      Thread.current[:vcap_user] = nil
      Thread.current[:vcap_token] = nil
    end

    def self.set(user, token = nil)
      Thread.current[:vcap_user] = user
      Thread.current[:vcap_token] = token
    end

    def self.current_user
      Thread.current[:vcap_user]
    end

    def self.current_user_is_admin?
      return admin_flag? || admin_scope?
    end

    def self.admin_flag?
      return current_user && current_user.admin?
    end

    def self.admin_scope?
      return !!(token && token['scope'] && token['scope'].include?('cloud_controller.admin'))
    end

    def self.token
      Thread.current[:vcap_token]
    end

    def self.current_user_email
      return token['email'] if token
    end

    def self.current_user_has_email?(email)
      current_user_email && current_user_email.downcase == email.downcase
    end
  end
end
