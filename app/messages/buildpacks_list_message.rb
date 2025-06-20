require 'messages/metadata_list_message'

module VCAP::CloudController
  class BuildpacksListMessage < MetadataListMessage
    register_allowed_keys %i[
      stacks
      names
      lifecycle
      page
      per_page
    ]

    validates :names, array: true, allow_nil: true
    validates :stacks, array: true, allow_nil: true
    validates :lifecycle,
              string: true,
              allow_nil: true,
              inclusion: { in: [VCAP::CloudController::Lifecycles::BUILDPACK, VCAP::CloudController::Lifecycles::CNB], message: 'must be either "buildpack" or "cnb"' }

    validates_with NoAdditionalParamsValidator

    def initialize(params={})
      super
      pagination_options.default_order_by = :lifecycle
      pagination_options.secondary_default_order_by = :position
    end

    def self.from_params(params)
      super(params, %w[names stacks])
    end

    def to_param_hash
      super(exclude: %i[page per_page])
    end

    def valid_order_by_values
      super + %i[position lifecycle]
    end
  end

  EmptyBuildpackListMessage = BuildpacksListMessage.from_params({}).freeze
end
