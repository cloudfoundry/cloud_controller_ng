require 'messages/base_message'
require 'messages/validators'
require 'messages/empty_lifecycle_data_message'

module VCAP::CloudController
  class DropletCreateMessage < BaseMessage
    register_allowed_keys %i[relationships process_types]

    validates_with NoAdditionalKeysValidator, RelationshipValidator
    validate :valid_process_types

    def valid_process_types
      return unless process_types

      unless process_types.is_a?(Hash)
        errors.add(:process_types, 'must be an object')
        return
      end

      errors.add(:process_types, 'key must not be empty') if process_types.keys.any?(&:empty?)

      return unless process_types.values.any? { |value| !value.is_a?(String) }

      errors.add(:process_types, 'value must be a string')
    end

    def relationships_message
      @relationships_message ||= Relationships.new(relationships.deep_symbolize_keys)
    end

    class Relationships < BaseMessage
      register_allowed_keys [:app]

      validates_with NoAdditionalKeysValidator

      validates :app, presence: true, allow_nil: false, to_one_relationship: true

      def app_guid
        HashUtils.dig(app, :data, :guid)
      end
    end
  end
end
