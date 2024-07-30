require 'messages/metadata_base_message'

module VCAP::CloudController
  class DeploymentCreateMessage < MetadataBaseMessage
    register_allowed_keys %i[
      relationships
      droplet
      revision
      strategy
      options
    ]

    validates_with NoAdditionalKeysValidator
    validates :strategy,
              inclusion: { in: %w[rolling canary], message: "'%<value>s' is not a supported deployment strategy" },
              allow_nil: true
    validate :mutually_exclusive_droplet_sources

    validates :options,
              allow_nil: true,
              hash: true

    validate :validate_max_in_flight

    def app_guid
      relationships&.dig(:app, :data, :guid)
    end

    def droplet_guid
      droplet&.dig(:guid)
    end

    def revision_guid
      revision&.dig(:guid)
    end

    def max_in_flight
      options&.dig(:max_in_flight) || 1
    end

    private

    def mutually_exclusive_droplet_sources
      return unless revision.present? && droplet.present?

      errors.add(:droplet, "Cannot set both fields 'droplet' and 'revision'")
    end

    def validate_max_in_flight
      return unless options.present? && options.is_a?(Hash) && options[:max_in_flight]

      max_in_flight = options[:max_in_flight]

      return unless !max_in_flight.is_a?(Integer) || max_in_flight < 1

      errors.add(:max_in_flight, 'must be an integer greater than 0')
    end
  end
end
