# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class ServiceAuthToken < Sequel::Model
    default_order_by  :label
    export_attributes :label, :provider
    import_attributes :label, :provider, :token

    strip_attributes  :label, :provider

    def validate
      validates_presence :label
      validates_presence :provider
      validates_presence :crypted_token
      validates_unique   [:label, :provider]
    end

    def token=(unencrypted_token)
      # nil is a valid argument to bcrypt::pw.create, hence the explict
      # nil check
      return if unencrypted_token.nil?
      self.crypted_token = BCrypt::Password.create(unencrypted_token)
    end

    def token_matches?(unencrypted_token)
      BCrypt::Password.new(crypted_token) == unencrypted_token
    end
  end
end
