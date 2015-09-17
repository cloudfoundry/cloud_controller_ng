require 'messages/base_message'

module VCAP::CloudController
  class AppUpdateMessage < BaseMessage
    ALLOWED_KEYS = [:name, :environment_variables, :buildpack]

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator

    validates :name, string: true, allow_nil: true
    validates :environment_variables, hash: true, allow_nil: true
    validates :buildpack, string: true, allow_nil: true

    def self.create_from_http_request(body)
      AppUpdateMessage.new(body.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
