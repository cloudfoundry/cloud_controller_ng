require 'messages/metadata_base_message'

module VCAP::CloudController
  class UserCreateMessage < MetadataBaseMessage
    register_allowed_keys %i[guid origin username]


    class UserCreateValidator < ActiveModel::Validator
      def validate(record)
        if record.guid
          record.errors.add(:username, message: "cannot be provided with 'guid'") if record.username
          record.errors.add(:origin, message: "cannot be provided with 'guid'") if record.origin
        elsif record.username || record.origin
          record.errors.add(:origin, message: "'username' is missing") unless record.username
          record.errors.add(:username, message: "'origin' is missing") unless record.origin
          record.errors.add(:origin, message: "cannot be 'uaa' when creating a user by username") unless record.origin != 'uaa'
        else
          record.errors.add(:guid, message: "either 'guid' or 'username' and 'origin' must be provided")
        end
      end
    end

    validates_with NoAdditionalKeysValidator
    validates :guid, guid: true, allow_nil: true
    validates :origin, string: true, allow_nil: true
    validates :username, string: true, allow_nil: true
    validates_with UserCreateValidator
  end
end
