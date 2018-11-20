require 'messages/list_message'

module VCAP::CloudController
  class BuildsListMessage < ListMessage
    register_allowed_keys [
      :app_guids,
      :states
    ]

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
