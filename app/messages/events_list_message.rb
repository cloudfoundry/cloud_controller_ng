require 'messages/list_message'

module VCAP::CloudController
  class EventsListMessage < ListMessage
    register_allowed_keys [
      :types,
      :target_guids,
      :space_guids,
      :organization_guids,
      :created_ats,
      :updated_ats
    ]

    validates_with NoAdditionalParamsValidator

    validates :types, array: true, allow_nil: true
    validates :target_guids, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true
    validates :created_ats, timestamp: true, allow_nil: true
    validates :updated_ats, timestamp: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(types target_guids space_guids organization_guids created_ats updated_ats))
    end
  end
end
