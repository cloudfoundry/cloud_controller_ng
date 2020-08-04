require 'messages/metadata_base_message'

module VCAP::CloudController
  class DropletUpdateMessage < MetadataBaseMessage
    register_allowed_keys [:image]

    validates :image, string: true, allow_nil: true
    validates_with NoAdditionalKeysValidator
  end
end
