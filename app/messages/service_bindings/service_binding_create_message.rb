require 'messages/base_message'

module VCAP::CloudController
  class ServiceBindingCreateMessage < BaseMessage
    ALLOWED_KEYS = [:type, :relationships, :data].freeze
    ALLOWED_TYPES = ['app'].freeze

    attr_accessor(*ALLOWED_KEYS)

    def self.create_from_http_request(body)
      ServiceBindingCreateMessage.new(body.deep_symbolize_keys)
    end

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
      attr_accessor :service_instance
      attr_accessor :app

      def allowed_keys
        [:service_instance, :app]
      end

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
      attr_accessor :parameters

      def allowed_keys
        [:parameters]
      end

      validates_with NoAdditionalKeysValidator
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
