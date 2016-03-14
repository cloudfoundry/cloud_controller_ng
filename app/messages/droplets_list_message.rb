require 'messages/base_message'

module VCAP::CloudController
  class DropletsListMessage < BaseMessage
    ALLOWED_KEYS = [:app_guids, :states, :page, :per_page, :order_by, :app_guid].freeze
    VALID_ORDER_BY_KEYS = /created_at|updated_at/

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalParamsValidator

    validates :app_guids, array: true, allow_nil: true
    validates :states, array: true, allow_nil: true
    validates_numericality_of :page, greater_than: 0, allow_nil: true, only_integer: true
    validates_numericality_of :per_page, greater_than: 0, allow_nil: true, only_integer: true
    validates_format_of :order_by, with: /[+-]?(#{VALID_ORDER_BY_KEYS})/, allow_nil: true

    validate :app_nested_request, if: -> { app_guid.present? }

    def initialize(params={})
      super(params.symbolize_keys)
    end

    def to_param_hash
      super(exclude: [:page, :per_page, :order_by, :app_guid])
    end

    def self.from_params(params)
      opts = params.dup
      ['states', 'app_guids'].each do |attribute|
        to_array! opts, attribute
      end
      new(opts.symbolize_keys)
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
