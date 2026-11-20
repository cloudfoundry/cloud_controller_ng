require 'messages/metadata_base_message'

module VCAP::CloudController
  class OrganizationUpdateMessage < MetadataBaseMessage
    register_allowed_keys %i[name suspended service_account_prefix]

    validates_with NoAdditionalKeysValidator

    validates :name,
              string: true,
              length: { minimum: 1, maximum: 255 },
              format: { with: ->(_) { Organization::ORG_NAME_REGEX }, message: 'must not contain escaped characters' },
              allow_nil: true

    validates :suspended,
              boolean: true,
              allow_nil: true

    validates :service_account_prefix,
              string: true,
              format: { with: ->(_) { Organization::SERVICE_ACCOUNT_PREFIX_REGEX },
                        message: 'must be a lowercase RFC 1123 label of 3-63 characters' },
              allow_nil: true
  end
end
