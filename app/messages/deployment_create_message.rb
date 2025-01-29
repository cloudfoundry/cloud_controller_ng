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

    validates :canary_steps,
              allow_nil: true,
              array: true

    validates :canary_options,
              allow_nil: true,
              hash: true

    validate :validate_canary_options

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

    def canary_steps
      return [] unless canary_options.present? && canary_options.is_a?(Hash)

      canary_options&.dig(:steps) || []
    end

    def canary_options
      return {} unless options.present? && options.is_a?(Hash)

      options&.dig(:canary) || {}
    end

    private

    def mutually_exclusive_droplet_sources
      return unless revision.present? && droplet.present?

      errors.add(:droplet, "Cannot set both fields 'droplet' and 'revision'")
    end

    def validate_canary_options
      return if canary_options.blank?

      errors.add(:canary_options, 'are only valid for Canary deployments') unless strategy == 'canary'
    end
  end
end
