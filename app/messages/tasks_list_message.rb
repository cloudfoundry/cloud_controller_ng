require 'messages/base_message'

module VCAP::CloudController
  class TasksListMessage < BaseMessage
    ALLOWED_KEYS = [:names, :states, :guids, :app_guids, :organization_guids, :space_guids, :page, :per_page, :app_guid].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalParamsValidator

    validates :names, array: true, allow_nil: true
    validates :states, array: true, allow_nil: true
    validates :guids, array: true, allow_nil: true
    validates :app_guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true
    validates_numericality_of :page, greater_than: 0, allow_nil: true, only_integer: true
    validates_numericality_of :per_page, greater_than: 0, allow_nil: true, only_integer: true

    validate :app_nested_request, if: -> { app_guid.present? }

    def initialize(params={})
      super(params.symbolize_keys)
    end

    def to_param_hash
      super(exclude: [:page, :per_page, :order_by, :app_guid])
    end

    def self.from_params(params)
      opts = params.dup
      ['names', 'states', 'guids', 'app_guids', 'organization_guids', 'space_guids'].each do |attribute|
        to_array! opts, attribute
      end
      new(opts.symbolize_keys)
    end

    private

    def app_nested_request
      invalid_guids = []
      invalid_guids << :space_guids if space_guids
      invalid_guids << :organization_guids if organization_guids
      invalid_guids << :app_guids if app_guids
      errors.add(:base, "Unknown query parameter(s): '#{invalid_guids.join("', '")}'") if invalid_guids.present?
    end

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
