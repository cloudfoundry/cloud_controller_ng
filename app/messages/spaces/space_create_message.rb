require 'messages/base_message'

module VCAP::CloudController
  class SpaceCreateMessage < BaseMessage
    ALLOWED_KEYS = [:name, :relationships].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator
    validates :name, presence: true
    validates :name,
      string: true,
      length: { maximum: 255 },
      format: { with: ->(_) { Space::SPACE_NAME_REGEX }, message: 'must not contain escaped characters' },
      allow_nil: true

    validates :organization_guid, presence: true, guid: true

    def self.create_from_http_request(body)
      new(body.deep_symbolize_keys)
    end

    def organization_guid
      HashUtils.dig(relationships, :organization, :data, :guid)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
