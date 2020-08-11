require 'messages/service_instance_message'
require 'presenters/helpers/censorship'
require 'utils/hash_utils'

module VCAP::CloudController
  class ServiceInstanceCreateMessage < ServiceInstanceMessage
    register_allowed_keys [
      :type,
      :relationships,
      :name,
      :tags,
    ]

    validates_with RelationshipValidator

    validates :type, allow_blank: false, inclusion: {
        in: %w(managed user-provided),
        message: "must be one of 'managed', 'user-provided'"
      }
    validates :name, string: true, presence: true
    validates :tags, array: true, allow_blank: true
    validate :tags_must_be_strings

    delegate :space_guid, to: :relationships_message

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    private

    def tags_must_be_strings
      if tags.present? && tags.is_a?(Array) && tags.any? { |i| !i.is_a?(String) }
        errors.add(:tags, 'must be a list of strings')
      end
    end

    class Relationships < BaseMessage
      register_allowed_keys [:space]

      validates :space, presence: true, allow_nil: false, to_one_relationship: true

      def space_guid
        HashUtils.dig(space, :data, :guid)
      end
    end
  end
end
