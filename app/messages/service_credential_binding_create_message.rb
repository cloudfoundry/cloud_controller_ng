module VCAP::CloudController
  class ServiceCredentialBindingCreateMessage < BaseMessage
    register_allowed_keys [:type, :name, :relationships]
    validates_with NoAdditionalKeysValidator, RelationshipValidator
    validates :type, allow_blank: false, inclusion: {
      in: %w(app),
      message: "must be 'app'"
    }

    delegate :service_instance_guid, to: :relationships_message
    delegate :app_guid, to: :relationships_message

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    class Relationships < BaseMessage
      register_allowed_keys [:service_instance, :app]
      validates_with NoAdditionalKeysValidator

      validates :service_instance, presence: true, allow_nil: false, to_one_relationship: true
      validates :app, presence: true, allow_nil: false, to_one_relationship: true

      def service_instance_guid
        HashUtils.dig(service_instance, :data, :guid)
      end

      def app_guid
        HashUtils.dig(app, :data, :guid)
      end
    end
  end
end
