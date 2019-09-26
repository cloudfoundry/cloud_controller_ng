require 'messages/list_message'

module VCAP::CloudController
  class EventsListMessage < ListMessage
    register_allowed_keys [
      :types,
      :target_guids,
      :space_guids,
      :organization_guids
    ]

    validates_with NoAdditionalParamsValidator

    validates :types, array: true, allow_nil: true
    validates :target_guids, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(types target_guids space_guids organization_guids))
    end
  end
end
