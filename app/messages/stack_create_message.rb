require 'messages/metadata_base_message'

module VCAP::CloudController
  class StackCreateMessage < MetadataBaseMessage
    register_allowed_keys %i[name description state]

    validates :name, presence: true, length: { maximum: 250 }
    validates :description, length: { maximum: 250 }
    validates :state, inclusion: { in: %w[ACTIVE DEPRECATED LOCKED DISABLED],
                                   message: 'must be one of [ACTIVE, DEPRECATED, LOCKED, DISABLED]' }, allow_nil: true
  end
end
