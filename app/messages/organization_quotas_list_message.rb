require 'messages/metadata_list_message'

module VCAP::CloudController
  class OrganizationQuotasListMessage < MetadataListMessage
    validates_with NoAdditionalParamsValidator

    def self.from_params(params)
      super(params, [])
    end
  end
end
