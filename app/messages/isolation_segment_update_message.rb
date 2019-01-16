require 'messages/metadata_base_message'

module VCAP::CloudController
  class IsolationSegmentUpdateMessage < MetadataBaseMessage
    register_allowed_keys [:name]

    validates_with NoAdditionalKeysValidator
    validates :name, string: true, allow_nil: true
  end
end
