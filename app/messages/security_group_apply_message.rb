require 'messages/to_many_relationship_message'

module VCAP::CloudController
  class SecurityGroupApplyMessage < ToManyRelationshipMessage
    def space_guids
      guids
    end
  end
end
