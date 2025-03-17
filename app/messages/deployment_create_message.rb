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

    ALLOWED_OPTION_KEYS = %i[
      canary
      max_in_flight
      web_instances
    ].freeze

    ALLOWED_STEP_KEYS = [
      :instance_weight
    ].freeze

    validates_with NoAdditionalKeysValidator
    validates :strategy,
              inclusion: { in: %w[rolling canary], message: "'%<value>s' is not a supported deployment strategy" },
              allow_nil: true
    validate :mutually_exclusive_droplet_sources

    validate :validate_options

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

    def web_instances
      options&.dig(:web_instances)
    end

    private

    def mutually_exclusive_droplet_sources
      return unless revision.present? && droplet.present?

      errors.add(:droplet, "Cannot set both fields 'droplet' and 'revision'")
    end

    def validate_options
      return if options.blank?

      unless options.is_a?(Hash)
        errors.add(:options, 'must be an object')
        return
      end

      disallowed_keys = options.keys - ALLOWED_OPTION_KEYS
      errors.add(:options, "has unsupported key(s): #{disallowed_keys.join(', ')}") if disallowed_keys.present?

      validate_web_instances if options[:web_instances]
      validate_max_in_flight if options[:max_in_flight]
      validate_canary if options[:canary]
    end

    def validate_max_in_flight
      max_in_flight = options[:max_in_flight]

      return unless !max_in_flight.is_a?(Integer) || max_in_flight < 1

      errors.add(:max_in_flight, 'must be an integer greater than 0')
    end

    def validate_web_instances
      web_instances = options[:web_instances]

      return unless !web_instances.is_a?(Integer) || web_instances < 1

      errors.add(:web_instances, 'must be an integer greater than 0')
    end

    def validate_canary
      canary_options = options[:canary]
      unless canary_options.is_a?(Hash)
        errors.add(:'options.canary', 'must be an object')
        return
      end

      if canary_options && strategy != 'canary'
        errors.add(:'options.canary', 'are only valid for Canary deployments')
        return
      end

      validate_steps if options[:canary][:steps]
    end

    def validate_steps
      steps = options[:canary][:steps]
      if !steps.is_a?(Array) || steps.any? { |step| !step.is_a?(Hash) }
        errors.add(:'options.canary.steps', 'must be an array of objects')
        return
      end

      steps.each do |step|
        disallowed_keys = step.keys - ALLOWED_STEP_KEYS

        errors.add(:'options.canary.steps', "has unsupported key(s): #{disallowed_keys.join(', ')}") if disallowed_keys.present?
      end

      validate_step_instance_weights
    end

    def validate_step_instance_weights
      steps = options[:canary][:steps]

      errors.add(:'options.canary.steps', 'missing key: "instance_weight"') if steps.any? { |step| !step.key?(:instance_weight) }

      if steps.any? { |step| !step[:instance_weight].is_a?(Integer) }
        errors.add(:'options.canary.steps.instance_weight', 'must be an Integer between 1-100 (inclusive)')
        return
      end

      errors.add(:'options.canary.steps.instance_weight', 'must be an Integer between 1-100 (inclusive)') if steps.any? { |step| (1..100).exclude?(step[:instance_weight]) }

      weights = steps.pluck(:instance_weight)
      return unless weights.sort != weights

      errors.add(:'options.canary.steps.instance_weight', 'must be sorted in ascending order')
    end
  end
end
