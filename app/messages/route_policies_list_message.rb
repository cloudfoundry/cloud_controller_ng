require 'messages/metadata_list_message'

module VCAP::CloudController
  class RoutePoliciesListMessage < MetadataListMessage
    register_allowed_keys %i[
      guids
      route_guids
      space_guids
      sources
      source_guids
      include
    ]

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: %w[source route]

    validates :route_guids, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true
    validates :source_guids, array: true, allow_nil: true
    validates :sources, array: true, allow_nil: true

    validate :sources_format_valid

    def self.from_params(params)
      super(params, %w[route_guids space_guids sources source_guids include])
    end

    private

    def sources_format_valid
      return unless sources.is_a?(Array)

      invalid = sources.reject { |s| s.is_a?(String) && RoutePolicy::SOURCE_REGEX.match?(s) }
      return if invalid.empty?

      errors.add(:sources, "contains invalid source format: #{invalid.join(', ')}")
    end
  end
end
