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
      super(params, %w(states))
    end
  end
end
