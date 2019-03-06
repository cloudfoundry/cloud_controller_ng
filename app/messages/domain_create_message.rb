require 'messages/metadata_base_message'

module VCAP::CloudController
  class DomainCreateMessage < MetadataBaseMessage
    register_allowed_keys [
      :name,
      :internal,
    ]
  end
end
