require 'messages/list_message'

module VCAP::CloudController
  class AppBuildsListMessage < ListMessage
    register_allowed_keys [
      :order_by,
      :page,
      :per_page,
      :states
    ]

    validates_with NoAdditionalParamsValidator

    validates :states, array: true, allow_nil: true

    def self.from_params(params)
      opts = params.dup
      %w(states).each do |attribute|
        to_array! opts, attribute
      end
      new(opts.symbolize_keys)
    end
  end
end
