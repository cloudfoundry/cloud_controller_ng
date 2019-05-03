require 'messages/metadata_list_message'

module VCAP::CloudController
  class BuildsListMessage < MetadataListMessage
    register_allowed_keys [
      :app_guids,
      :states,
    ]

    validates_with NoAdditionalParamsValidator

    validates :app_guids, array: true, allow_nil: true
    validates :states, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(states app_guids))
    end
  end
end
