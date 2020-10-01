require 'messages/list_message'

module VCAP::CloudController
  class RolesListMessage < ListMessage
    register_allowed_keys [
      :organization_guids,
      :space_guids,
      :user_guids,
      :types,
      :include
    ]

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: %w(user organization space)

    validates :organization_guids, allow_nil: true, array: true
    validates :space_guids, allow_nil: true, array: true
    validates :user_guids, allow_nil: true, array: true
    validates :types, allow_nil: true, array: true

    def self.from_params(params)
      params['order_by'] ||= 'created_at'

      super(params, %w(organization_guids space_guids user_guids types include))
    end
  end
end
