require 'messages/metadata_list_message'

module VCAP::CloudController
  class OrganizationQuotasListMessage < ListMessage
    validates_with NoAdditionalParamsValidator

    register_allowed_keys [
      :names,
      :organization_guids
    ]

    validates :names, allow_nil: true, array: true
    validates :organization_guids, allow_nil: true, array: true

    def self.from_params(params)
      super(params, %w(names organization_guids))
    end
  end
end
