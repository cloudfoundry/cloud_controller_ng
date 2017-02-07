require 'messages/list_message'

module VCAP::CloudController
  class TasksListMessage < ListMessage
    ALLOWED_KEYS = [:names, :states, :guids, :app_guids, :organization_guids, :space_guids, :page, :per_page, :order_by, :app_guid, :sequence_ids].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalParamsValidator # from BaseMessage

    validates :names, array: true, allow_nil: true
    validates :states, array: true, allow_nil: true
    validates :guids, array: true, allow_nil: true
    validates :app_guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true
    validate :app_nested_request, if: -> { app_guid.present? }
    validate :non_app_nested_request, if: -> { !app_guid.present? }
    validates :sequence_ids, array: true, allow_nil: true

    def initialize(params={})
      super(params.symbolize_keys)
    end

    def to_param_hash
      super(exclude: [:page, :per_page, :order_by, :app_guid])
    end

    def self.from_params(params)
      opts = params.dup
      %w(names states guids app_guids organization_guids space_guids sequence_ids).each do |attribute|
        to_array! opts, attribute
      end
      new(opts.symbolize_keys)
    end

    private

    def app_nested_request
      invalid_params = []
      invalid_params << :space_guids if space_guids
      invalid_params << :organization_guids if organization_guids
      invalid_params << :app_guids if app_guids
      errors.add(:base, "Unknown query parameter(s): '#{invalid_params.join("', '")}'") if invalid_params.present?
    end

    def non_app_nested_request
      invalid_params = []
      invalid_params << :sequence_ids if sequence_ids
      errors.add(:base, "Unknown query parameter(s): '#{invalid_params.join("', '")}'") if invalid_params.present?
    end

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
