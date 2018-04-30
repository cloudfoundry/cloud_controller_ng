require 'messages/list_message'

module VCAP::CloudController
  class DeploymentsListMessage < ListMessage
    register_allowed_keys [
      :order_by,
      :page,
      :per_page,
      :app_guids
    ]

    validates_with NoAdditionalParamsValidator

    validates :app_guids, array: true, allow_nil: true

    def self.from_params(params)
      opts = params.dup.symbolize_keys
      to_array! opts, :app_guids
      new(opts)
    end
  end
end
