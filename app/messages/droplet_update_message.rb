require 'messages/metadata_base_message'

module VCAP::CloudController
  class DropletUpdateMessage < MetadataBaseMessage
    register_allowed_keys [:image, :cache_id, :relationships]

    validates_with NoAdditionalKeysValidator
  end
end
