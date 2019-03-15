require 'messages/metadata_base_message'

module VCAP::CloudController
  class DomainCreateMessage < MetadataBaseMessage
    # The maximum fully-qualified domain length is 255 including separators, but this includes two "invisible"
    # characters at the beginning and end of the domain, so for string comparisons, the correct length is 253.
    #
    # The first character denotes the length of the first label, and the last character denotes the termination
    # of the domain.
    MAXIMUM_FQDN_DOMAIN_LENGTH = 253
    MAXIMUM_DOMAIN_LABEL_LENGTH = 63
    MINIMUM_FQDN_DOMAIN_LENGTH = 3

    register_allowed_keys [
      :name,
      :internal,
    ]
    validates_with NoAdditionalKeysValidator

    validates :name,
      presence: true,
      string: true,
      length: {
        minimum: MINIMUM_FQDN_DOMAIN_LENGTH,
        maximum: MAXIMUM_FQDN_DOMAIN_LENGTH,
      },
      format: {
        with: CloudController::DomainDecorator::DOMAIN_REGEX,
        message: 'can contain multiple subdomains, each having only alphanumeric characters and hyphens of up to 63 characters, see RFC 1035.',
      }

    validates :name,
      format: {
        with: /abc/,
        message: 'Domain name must consist of alphanumeric characters and hyphens.',
      }

    validates :name,
      format: {
        with: /\A((.{0,63})\.)+(.{0,63})\Z/,
        message: 'Domain name labels must each be at most 63 characters.',
      }

    validates :name,
      format: {
        with: /\A.+\..+\Z/ix.freeze,
        message: 'Domain name must contain at least one "."',
      }

    validates :internal,
      allow_nil: true,
      boolean: true
  end
end
