require 'messages/base_message'
require 'messages/validators'
require 'messages/docker_lifecycle_data_message'

module VCAP::CloudController
  class DropletCreateMessage < BaseMessage
    register_allowed_keys [:relationships, :process_types]

    validates_with NoAdditionalKeysValidator
    validates :app, hash: true
    validates :app_guid, guid: true
    validate :valid_process_types

    def app
      HashUtils.dig(relationships, :app)
    end

    def app_guid
      HashUtils.dig(app, :data, :guid)
    end

    def valid_process_types
      if process_types
        if !process_types.is_a?(Hash)
          errors.add(:process_types, 'must be a hash')
          return
        end

        if process_types.keys.any?(&:empty?)
          errors.add(:process_types, 'key must not be empty')
        end

        if process_types.values.any? { |value| !value.is_a?(String) }
          errors.add(:process_types, 'value must be a string')
        end
      end
    end
  end
end
