require 'messages/base_message'

module VCAP::CloudController
  class AppUpdateMessage < BaseMessage
    attr_accessor :name, :environment_variables, :buildpack

    def allowed_keys
      [:name, :environment_variables, :buildpack]
    end

    validates_with NoAdditionalKeysValidator

    validates :name, string: true, allow_nil: true
    validates :environment_variables, hash: true, allow_nil: true
    validates :buildpack, string: true, allow_nil: true

    def self.create_from_http_request(body)
      AppUpdateMessage.new(body.symbolize_keys)
    end
  end
end
