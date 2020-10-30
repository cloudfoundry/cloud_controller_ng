require 'messages/metadata_base_message'
require 'utils/hash_utils'

module VCAP::CloudController
  class ServiceRouteBindingCreateMessage < MetadataBaseMessage
    register_allowed_keys [:relationships, :parameters]

    validates_with NoAdditionalKeysValidator, RelationshipValidator
    validates :parameters, hash: true, allow_nil: true

    delegate :route_guid, :service_instance_guid, to: :relationships_message

    def relationships_message
      @relationships_message ||= Relationships.new(relationships.deep_symbolize_keys)
    end

    class Relationships < BaseMessage
      register_allowed_keys [:service_instance, :route]

      def route_guid
        HashUtils.dig(route, :data, :guid)
      end

      def service_instance_guid
        HashUtils.dig(service_instance, :data, :guid)
      end

      validates_with NoAdditionalKeysValidator

      validates :service_instance, presence: true, allow_nil: false, to_one_relationship: true
      validates :route, presence: true, allow_nil: false, to_one_relationship: true
    end
  end
end
