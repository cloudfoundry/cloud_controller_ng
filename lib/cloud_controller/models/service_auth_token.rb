# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class ServiceAuthToken < Sequel::Model
    default_order_by  :label
    export_attributes :id, :label, :provider, :created_at, :updated_at
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
  end
end
