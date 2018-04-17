require 'messages/list_message'

module VCAP::CloudController
  class BuildsListMessage < ListMessage
    ALLOWED_KEYS = [
      :app_guids,
      :order_by,
      :page,
      :per_page,
      :states
    ].freeze

    attr_accessor(*ALLOWED_KEYS)
    validates_with NoAdditionalParamsValidator

    validates :app_guids, array: true, allow_nil: true
    validates :states, array: true, allow_nil: true

    def self.from_params(params)
      opts = params.dup
      %w(states app_guids).each do |attribute|
        to_array! opts, attribute
      end
      new(opts.symbolize_keys)
    end
  end
end
