require 'messages/base_message'

module VCAP::CloudController
  class AppCreateMessage < BaseMessage
    attr_accessor :name, :space_guid, :environment_variables

    def allowed_keys
      [:name, :space_guid, :environment_variables]
    end

    validates_with NoAdditionalKeysValidator

    validates :name, string: true
    validates :space_guid, guid: true
    validates :environment_variables, hash: true, allow_nil: true

    def self.create_from_http_request(body)
      AppCreateMessage.new(body.symbolize_keys)
    end
  end
end
