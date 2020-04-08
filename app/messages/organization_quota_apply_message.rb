require 'messages/to_many_relationship_message'

module VCAP::CloudController
  class OrganizationQuotaApplyMessage < ToManyRelationshipMessage
    def organization_guids
      guids
    end
  end
end
