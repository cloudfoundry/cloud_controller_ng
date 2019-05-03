require 'messages/metadata_list_message'

module VCAP::CloudController
  class AppBuildsListMessage < MetadataListMessage
    register_allowed_keys [
      :states,
    ]

    validates_with NoAdditionalParamsValidator

    validates :states, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(states))
    end
  end
end
