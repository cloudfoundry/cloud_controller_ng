require 'messages/list_message'

module VCAP::CloudController
  class EventsListMessage < ListMessage
    register_allowed_keys [
      :types,
      :target_guids,
      :space_guids,
      :organization_guids,
      :created_ats
    ]

    validates_with NoAdditionalParamsValidator

    def self.from_params(params)
      to_array_keys = %w(types target_guids space_guids organization_guids created_ats)
      comparable_keys = %w(created_ats)
      super(params, to_array_keys, comparable_keys)
    end
  end
end
