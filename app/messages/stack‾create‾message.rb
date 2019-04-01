require 'messages/metadata_base_message'

module VCAP::CloudController
  class StackCreateMessage < MetadataBaseMessage
    register_allowed_keys [:name, :description]

    validates :name, presence: true, length: { maximum: 250 }
    validates :description, length: { maximum: 250 }
  end
end
