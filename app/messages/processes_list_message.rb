require 'messages/list_message'

module VCAP::CloudController
  class ProcessesListMessage < ListMessage
    ALLOWED_KEYS = [:page, :per_page, :app_guid, :types, :space_guids, :organization_guids, :app_guids].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalParamsValidator # from BaseMessage

    validates :types, array: true, allow_nil: true
    validates :app_guids, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true
    validate :app_nested_request, if: -> { app_guid.present? }

    def initialize(params={})
      super(params.symbolize_keys)
    end

    def self.from_params(params)
      opts = params.dup
      ['types', 'space_guids', 'organization_guids', 'app_guids'].each do |param|
        to_array!(opts, param)
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
      invalid_guids << :organization_guids if organization_guids
      invalid_guids << :space_guids if space_guids
      errors.add(:base, "Unknown query parameter(s): '#{invalid_guids.join("', '")}'") if invalid_guids.present?
    end

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
