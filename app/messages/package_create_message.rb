require 'messages/base_message'

module VCAP::CloudController
  class PackageCreateMessage < BaseMessage
    attr_accessor :app_guid, :type, :url

    def allowed_keys
      [:type, :app_guid, :url]
    end

    validates_with NoAdditionalKeysValidator

    validates :type, inclusion: { in: %w(bits docker), message: 'must be one of \'bits, docker\'' }
    validates :app_guid, guid: true
    validates :url, absence: { absence: true, message: 'must be blank when type is bits' }, if: "type == 'bits'"
    validates :url, presence: { presence: true, message: "can't be blank type is docker" }, if: "type == 'docker'"

    def self.create_from_http_request(app_guid, body)
      PackageCreateMessage.new(body.symbolize_keys.merge({ app_guid: app_guid }))
    end
  end
end
