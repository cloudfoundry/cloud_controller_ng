require 'messages/metadata_list_message'

module VCAP::CloudController
  class AppRevisionsListMessage < MetadataListMessage
    register_allowed_keys [
      :versions,
    ]

    validates_with NoAdditionalParamsValidator

    validates :versions, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(versions))
    end
  end
end
