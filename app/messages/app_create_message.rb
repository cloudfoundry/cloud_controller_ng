require 'messages/base_message'

module VCAP::CloudController
  class AppCreateMessage < BaseMessage
    ALLOWED_KEYS = [:name, :environment_variables, :buildpack, :relationships]

    attr_accessor(*ALLOWED_KEYS)

    validates_with RelationshipValidator

    validates :name, string: true
    validates :environment_variables, hash: true, allow_nil: true
    validates :buildpack, string: true, allow_nil: true
    validates :relationships, hash: true, presence: true, allow_nil: false

    def space_guid
      relationships.try(:[], 'space').try(:[], 'guid') ||
        relationships.try(:[], :space).try(:[], :guid)
    end

    class Relationships < BaseMessage
      attr_accessor :space

      def allowed_keys
        [:space]
      end

      validates_with NoAdditionalKeysValidator

      validates :space, presence: true, allow_nil: false, to_one_relationship: true
    end

    def self.create_from_http_request(body)
      AppCreateMessage.new(body.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
