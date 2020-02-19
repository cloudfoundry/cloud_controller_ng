require 'messages/base_message'
require 'messages/validators'

module VCAP::CloudController
  class SecurityGroupCreateMessage < BaseMessage
    register_allowed_keys [:name, :rules]

    validates :name, presence: true

    validates :rules, allow_nil: true, array: true

    # # Relationships validations
    # delegate :organization_guid, to: :relationships_message
    # delegate :space_guids, to: :relationships_message

    # def relationships_message
    #   @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    # end

    # class Relationships < BaseMessage
    #   register_allowed_keys [:organization, :spaces]

    #   validates :spaces, allow_nil: true, to_many_relationship: true

    #   def organization_guid
    #     HashUtils.dig(organization, :data, :guid)
    #   end

    #   def space_guids
    #     space_data = HashUtils.dig(spaces, :data)
    #     space_data ? space_data.map { |space| space[:guid] } : []
    #   end
    # end
  end
end
