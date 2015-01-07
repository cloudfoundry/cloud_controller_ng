module VCAP::CloudController
  class ServiceAuthToken < Sequel::Model
    export_attributes :label, :provider
    import_attributes :label, :provider, :token

    strip_attributes :label, :provider

    many_to_one :service, key: [:label, :provider], primary_key: [:label, :provider]

    encrypt :token, salt: :salt

    def validate
      validates_presence :label
      validates_presence :provider
      validates_presence :token
      validates_unique [:label, :provider]
    end

    def token_matches?(unencrypted_token)
      token == unencrypted_token
    end
  end
end
