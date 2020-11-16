module VCAP::CloudController
  class ServiceCredentialAppBindingCreateMessage < ServiceCredentialBindingCreateMessage
    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    delegate :app_guid, to: :relationships_message

    class Relationships < ServiceCredentialBindingCreateMessage::Relationships
      register_allowed_keys [:app]
      validates_with NoAdditionalKeysValidator

      validates :app, presence: true, allow_nil: false, to_one_relationship: true

      def app_guid
        HashUtils.dig(app, :data, :guid)
      end
    end
  end
end
