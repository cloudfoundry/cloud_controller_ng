require 'messages/list_message'

module VCAP::CloudController
  class ServiceAccountsListMessage < ListMessage
    register_allowed_keys %i[names space_guids]
    validates_with NoAdditionalParamsValidator
    validates :names, :space_guids, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w[names space_guids])
    end

    def valid_order_by_values
      super + [:name]
    end
  end
end
