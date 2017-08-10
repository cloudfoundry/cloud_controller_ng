require 'messages/base_message'

module VCAP::CloudController
  class SpaceCreateMessage < BaseMessage
    ALLOWED_KEYS = [:name, :relationships].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator,
      RelationshipValidator

    validates :name, presence: true
    validates :name,
      string: true,
      length: { maximum: 255 },
      format: { with: ->(_) { Space::SPACE_NAME_REGEX }, message: 'must not contain escaped characters' },
      allow_nil: true

    delegate :organization_guid, to: :relationships_message

    def self.create_from_http_request(body)
      new(body.deep_symbolize_keys)
    end

    def relationships_message
      @relationships_message ||= Relationships.new(relationships.deep_symbolize_keys)
    end

    private

    class Relationships < BaseMessage
      attr_accessor :organization

      def allowed_keys
        [:organization]
      end

      validates_with NoAdditionalKeysValidator

      validates :organization, presence: true, allow_nil: false, to_one_relationship: true

      def organization_guid
        HashUtils.dig(organization, :data, :guid)
      end
    end

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
