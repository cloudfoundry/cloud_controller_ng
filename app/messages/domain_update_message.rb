require 'messages/metadata_base_message'

module VCAP::CloudController
  class DomainUpdateMessage < MetadataBaseMessage
    register_allowed_keys [:guid]

    validates_with NoAdditionalKeysValidator

    validates :guid, presence: true, string: true
  end
end
