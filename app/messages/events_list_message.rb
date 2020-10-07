require 'messages/list_message'

module VCAP::CloudController
  class EventsListMessage < ListMessage
    register_allowed_keys [
      :types,
      :target_guids,
      :space_guids,
      :organization_guids,
    ]

    validates_with NoAdditionalParamsValidator
    validates_with TargetGuidsValidator, allow_nil: true

    validates :types, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true

    def exclude_target_guids?
      return (target_guids.is_a? Hash) && target_guids[:not].present?
    end

    def self.from_params(params)
      if params[:target_guids].is_a? Hash
        super(params, %w(types space_guids organization_guids), fields: %w(target_guids))
      else
        super(params, %w(types target_guids space_guids organization_guids))
      end
    end
  end
end
