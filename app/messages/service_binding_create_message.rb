require 'messages/base_message'

module VCAP::CloudController
  class ServiceBindingCreateMessage < BaseMessage
    ALLOWED_KEYS = [:type, :relationships, :data].freeze
    ALLOWED_TYPES = ['app'].freeze

    attr_accessor(*ALLOWED_KEYS)

    def self.create_from_http_request(body)
      ServiceBindingCreateMessage.new(body.symbolize_keys)
    end

    validates_with NoAdditionalKeysValidator, RelationshipValidator, DataValidator
    validates :service_instance_guid, string: true
    validates :app_guid, string: true
    validates :data, hash: true, allow_nil: true
    validates :type, string: true, presence: true
    validates_inclusion_of :type, in: ALLOWED_TYPES, message: 'type must be app'

    def app_guid
      relationships.try(:[], 'app').try(:[], 'guid') ||
        relationships.try(:[], :app).try(:[], :guid)
    end

    def service_instance_guid
      relationships.try(:[], 'service_instance').try(:[], 'guid') ||
        relationships.try(:[], :service_instance).try(:[], :guid)
    end

    def parameters
      data.try(:[], 'parameters') ||
        data.try(:[], :parameters)
    end

    class Relationships < BaseMessage
      attr_accessor :service_instance
      attr_accessor :app

      def allowed_keys
        [:service_instance, :app]
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
