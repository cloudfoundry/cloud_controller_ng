require 'messages/base_message'

module VCAP::CloudController
  class OrganizationCreateMessage < BaseMessage
    ALLOWED_KEYS = [:name].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator
    validates :name, presence: true
    validates :name,
      string: true,
      length: { maximum: 255 },
      format: { with: ->(_) { Organization::ORG_NAME_REGEX }, message: 'must not contain escaped characters' },
      allow_nil: true

    def self.create_from_http_request(body)
      OrganizationCreateMessage.new(body.deep_symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
