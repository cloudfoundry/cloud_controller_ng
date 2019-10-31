require 'messages/list_message'

module VCAP::CloudController
  class RolesListMessage < ListMessage
    validates_with NoAdditionalParamsValidator

    def self.from_params(params)
      params = params.symbolize_keys
      params[:order_by] ||= 'created_at'

      super(params, [])
    end
  end
end
