require 'messages/to_many_relationship_message'

module VCAP::CloudController
  class SpaceQuotaApplyMessage < ToManyRelationshipMessage
    # validates_with DataParamGUIDValidator, related_resource: :space

    def space_guids
      guids
    end
  end
end
