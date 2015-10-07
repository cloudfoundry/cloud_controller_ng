require 'messages/base_message'

module VCAP::CloudController
  class PackageCreateMessage < BaseMessage
    ALLOWED_KEYS = [:app_guid, :type, :url, :data]

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator

    validates :type, inclusion: { in: %w(bits docker), message: 'must be one of \'bits, docker\'' }
    validates :app_guid, guid: true
    validates :url, absence: { absence: true, message: 'must be blank when type is bits' }, if: "type == 'bits'"
    validates :url, presence: { presence: true, message: 'can not be blank when type is docker' }, if: "type == 'docker'"

    validates :data, inclusion: { in: [{}],
                                  message: 'data must be empty if provided for bits packages',
                                  if: 'type == "bits"',
                                  allow_nil: true }

    def self.create_from_http_request(app_guid, body)
      PackageCreateMessage.new(body.symbolize_keys.merge({ app_guid: app_guid }))
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
