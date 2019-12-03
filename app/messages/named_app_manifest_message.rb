require 'messages/app_manifest_message'
require 'messages/validators'

module VCAP::CloudController
  class NamedAppManifestMessage < AppManifestMessage
    register_allowed_keys [:name]

    validates :name, presence: { message: 'must not be empty' }, string: true
    validate :validate_name_dns_compliant!

    def validate_name_dns_compliant!
      if name.present? && name.length > 63
        if routes.nil? || routes.empty?
          errors.add(:name, 'cannot exceed 63 characters when routes are not present')
        end
      end

      unless name&.match(/\A[\w\-]+\z/)
        if routes.nil? || routes.empty?
          errors.add(:name, 'must contain only alphanumeric characters, "_", or "-" when routes are not present')
        end
      end
    end
  end
end
