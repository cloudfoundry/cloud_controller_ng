require 'messages/metadata_base_message'

module VCAP::CloudController
  class StackUpdateMessage < MetadataBaseMessage
    register_allowed_keys [:state, :description]

    validates_with NoAdditionalKeysValidator

    validates :state, inclusion: { in: %w[ACTIVE DEPRECATED LOCKED DISABLED],
                                   message: 'must be one of [ACTIVE, DEPRECATED, LOCKED, DISABLED]' }, allow_nil: true
    validates :description, length: { maximum: 250 }
  end
end
