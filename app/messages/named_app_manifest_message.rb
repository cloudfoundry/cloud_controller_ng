require 'messages/app_manifest_message'
require 'messages/validators'

module VCAP::CloudController
  class NamedAppManifestMessage < AppManifestMessage
    register_allowed_keys [:name]

    validates :name, presence: { message: 'must not be empty' }, string: true
    validate :validate_name_dns_compliant!, if: -> { default_route }

    def validate_name_dns_compliant!
      prefix = 'Failed to create default route from app name:'

      if name.present? && name.length > 63
        errors.add(prefix, 'Host cannot exceed 63 characters')
      end

      unless name&.match(/\A[\w\-]+\z/)
        errors.add(prefix, 'Host must be either "*" or contain only alphanumeric characters, "_", or "-"')
      end
    end
  end
end
