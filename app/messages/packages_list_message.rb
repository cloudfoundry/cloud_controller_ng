require 'messages/list_message'

module VCAP::CloudController
  class PackagesListMessage < ListMessage
    ALLOWED_KEYS = [:page, :per_page, :states, :types, :guids, :app_guids, :app_guid].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalParamsValidator

    validates :states, array: true, allow_nil: true
    validates :types,  array: true, allow_nil: true
    validates :guids,  array: true, allow_nil: true
    validates :app_guids, array: true, allow_nil: true
    validate :app_nested_request, if: -> { app_guid.present? }

    def initialize(params={})
      super(params.symbolize_keys)
    end

    def self.from_params(params)
      opts = params.dup
      ['types', 'states', 'guids', 'app_guids'].each do |attribute|
        to_array! opts, attribute
      end
      new(opts.symbolize_keys)
    end

    def to_param_hash
      super(exclude: [:page, :per_page, :app_guid])
    end

    private

    def app_nested_request
      invalid_guids = []
      invalid_guids << :app_guids if app_guids
      errors.add(:base, "Unknown query parameter(s): '#{invalid_guids.join("', '")}'") if invalid_guids.present?
    end

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
