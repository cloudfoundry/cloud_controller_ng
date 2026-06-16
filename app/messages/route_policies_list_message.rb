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

    validates :space_guids, array: true, allow_nil: true
    validates :source_guids, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w[route_guids space_guids sources source_guids include])
    end
  end
end
