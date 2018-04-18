require 'messages/base_message'

module VCAP::CloudController
  class ServiceBindingCreateMessage < BaseMessage
    register_allowed_keys [:type, :name, :relationships, :data]
    ALLOWED_TYPES = ['app'].freeze

    validates_with NoAdditionalKeysValidator, RelationshipValidator, DataValidator

    validates :data, hash: true, allow_nil: true
    validates :type, string: true, presence: true
    validates_inclusion_of :type, in: ALLOWED_TYPES, message: 'type must be app'

    delegate :app_guid, :service_instance_guid, to: :relationships_message

    def parameters
      HashUtils.dig(data, :parameters)
    end

    def relationships_message
      @relationships_message ||= Relationships.new(relationships.deep_symbolize_keys)
    end

    class Relationships < BaseMessage
      register_allowed_keys [:service_instance, :app]

      def app_guid
        HashUtils.dig(app, :data, :guid)
      end

      def service_instance_guid
        HashUtils.dig(service_instance, :data, :guid)
      end

      validates_with NoAdditionalKeysValidator

      validates :service_instance, presence: true, allow_nil: false, to_one_relationship: true
      validates :app, presence: true, allow_nil: false, to_one_relationship: true
    end

    class Data < BaseMessage
      register_allowed_keys [:parameters]

      validates_with NoAdditionalKeysValidator
    end
  end
end
