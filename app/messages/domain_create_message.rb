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
        message: 'does not comply with RFC 1035 standards',
      }

    validates :name,
      format: {
        with: /\./.freeze,
        message: 'must contain at least one "."',
      }

    validates :name,
      format: {
        with: /\A((.{0,63})\.)?+(.{0,63})\Z/,
        message: 'subdomains must each be at most 63 characters',
      }

    validate :alpha_numeric

    validates :internal,
      allow_nil: true,
      boolean: true

    private

    def alpha_numeric
      if /[^a-z0-9\-\.]/i.match?(name.to_s)
        errors.add(:name, 'must consist of alphanumeric characters and hyphens')
      end
    end
  end
end
