require 'messages/metadata_base_message'

module VCAP::CloudController
  class MetadataUpdateMessage < MetadataBaseMessage
    register_allowed_keys []

    validates_with NoAdditionalKeysValidator
  end
end
