require 'messages/metadata_base_message'

module VCAP::CloudController
  class UserCreateMessage < MetadataBaseMessage
    register_allowed_keys [:guid]

    validates_with NoAdditionalKeysValidator
    validates :guid, guid: true
  end
end
