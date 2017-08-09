require 'messages/list_message'

module VCAP::CloudController
  class SpacesListMessage < ListMessage
    ALLOWED_KEYS = [:page, :per_page, :order_by, :names, :organization_guids].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalParamsValidator

    validates :names, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true

    def initialize(params={})
      super(params.symbolize_keys)
    end

    def self.from_params(params)
      opts = params.dup
      to_array! opts, 'names'
      to_array! opts, 'organization_guids'
      new(opts.symbolize_keys)
    end

    def valid_order_by_values
      super << :name
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
