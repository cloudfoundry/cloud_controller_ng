require 'messages/metadata_base_message'

module VCAP::CloudController
  class UserCreateMessage < MetadataBaseMessage
    register_allowed_keys [:guid]

    validates_with NoAdditionalKeysValidator
    validate :alpha_numeric
    validates :guid, string: true, presence: true, length: { minimum: 1, maximum: 250 }

    private

    def alpha_numeric
      if /[^a-z0-9\-\.]/i.match?(guid.to_s)
        errors.add(:guid, 'must consist of alphanumeric characters and hyphens')
      end
    end
  end
end
