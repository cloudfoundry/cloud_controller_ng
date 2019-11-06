require 'messages/list_message'

module VCAP::CloudController
  class RolesListMessage < ListMessage
    register_allowed_keys [
      :guids,
      :organization_guids,
      :space_guids,
      :user_guids,
      :types
    ]

    validates_with NoAdditionalParamsValidator

    validates :guids, allow_nil: true, array: true
    validates :organization_guids, allow_nil: true, array: true
    validates :space_guids, allow_nil: true, array: true
    validates :user_guids, allow_nil: true, array: true
    validates :types, allow_nil: true, array: true

    def self.from_params(params)
      params['order_by'] ||= 'created_at'

      super(params, %w(guids organization_guids space_guids user_guids types))
    end
  end
end
