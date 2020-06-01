require 'messages/list_message'

module VCAP::CloudController
  class UsageEventsListMessage < ListMessage
    def self.from_params(params)
      params['order_by'] ||= 'created_at'
      super(params, [])
    end
  end
end
