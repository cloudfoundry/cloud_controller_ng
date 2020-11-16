module VCAP::CloudController
  class ServiceCredentialKeyBindingCreateMessage < ServiceCredentialBindingCreateMessage
    validates :name, string: true, presence: true

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    class Relationships < ServiceCredentialBindingCreateMessage::Relationships
      validates_with NoAdditionalKeysValidator
    end
  end
end
