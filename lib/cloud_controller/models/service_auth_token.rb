# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class ServiceAuthToken < Sequel::Model
    default_order_by  :label
    export_attributes :label, :provider
    import_attributes :label, :provider, :token

    strip_attributes  :label, :provider

    many_to_one   :service, :key => [:label, :provider], :primary_key => [:label, :provider]

    def validate
      validates_presence :label
      validates_presence :provider
      validates_presence :token
      validates_unique   [:label, :provider]
    end

    def token_matches?(unencrypted_token)
      token == unencrypted_token
    end

    def token=(value)
      generate_salt
      super(VCAP::CloudController::Encryptor.encrypt(value, salt))
    end

    def token
      return unless super
      VCAP::CloudController::Encryptor.decrypt(super, salt)
    end

    def generate_salt
      self.salt ||= VCAP::CloudController::Encryptor.generate_salt
    end
  end
end
