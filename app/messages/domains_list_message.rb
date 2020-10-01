require 'messages/metadata_list_message'

module VCAP::CloudController
  class DomainsListMessage < MetadataListMessage
    register_allowed_keys [
      :names,
      :guids,
      :organization_guids,
    ]

    validates_with NoAdditionalParamsValidator
    validates :names, allow_nil: true, array: true
    validates :organization_guids, allow_nil: true, array: true

    def self.from_params(params)
      super(params, %w(names organization_guids))
    end
  end
end
