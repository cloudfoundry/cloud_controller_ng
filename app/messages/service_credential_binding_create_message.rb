require 'messages/metadata_base_message'
module VCAP::CloudController
  class ServiceCredentialBindingCreateMessage < MetadataBaseMessage
    register_allowed_keys [:type, :name, :relationships, :parameters]
    validates_with NoAdditionalKeysValidator, RelationshipValidator
    validates :parameters, hash: true, allow_nil: true
    validates :type, allow_blank: false, inclusion: {
      in: %w(app key),
      message: "must be 'app' or 'key'"
    }

    delegate :service_instance_guid, to: :relationships_message

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    class Relationships < BaseMessage
      register_allowed_keys [:service_instance]

      validates :service_instance, presence: true, allow_nil: false, to_one_relationship: true

      def service_instance_guid
        HashUtils.dig(service_instance, :data, :guid)
      end
    end
  end
end
