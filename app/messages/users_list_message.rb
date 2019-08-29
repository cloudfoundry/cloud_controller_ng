require 'messages/metadata_list_message'

module VCAP::CloudController
  class UsersListMessage < MetadataListMessage
    register_allowed_keys [:guids]

    validates_with NoAdditionalParamsValidator
    validates :guids, allow_nil: true, array: true

    def self.from_params(params)
      super(params, %w(guids))
    end
  end
end
