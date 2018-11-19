require 'messages/list_message'

module VCAP::CloudController
  class AppRevisionsListMessage < ListMessage
    register_allowed_keys [
      :order_by,
      :page,
      :per_page,
    ]

    validates_with NoAdditionalParamsValidator

    def self.from_params(params)
      super(params, [])
    end
  end
end
