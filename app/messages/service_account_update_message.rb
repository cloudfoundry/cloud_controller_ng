require 'messages/metadata_base_message'

module VCAP::CloudController
  class ServiceAccountUpdateMessage < MetadataBaseMessage
    register_allowed_keys %i[description enabled]
    validates :enabled, boolean: true, if: -> { requested?(:enabled) }
    validates_with NoAdditionalKeysValidator
    validates :description, string: true, allow_nil: true, length: { maximum: 250 }
  end
end
