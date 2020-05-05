require 'messages/service_instance_create_message'
require 'utils/hash_utils'

module VCAP::CloudController
  class ServiceInstanceCreateManagedMessage < ServiceInstanceCreateMessage
    register_allowed_keys [
      :parameters
    ]

    validates_with NoAdditionalKeysValidator

    validates :parameters, hash: true, allow_nil: true
    validates :type, allow_blank: false, inclusion: {
      in: %w(managed),
      message: "must be 'managed'"
    }

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    delegate :service_plan_guid, to: :relationships_message

    class Relationships < ServiceInstanceCreateMessage::Relationships
      register_allowed_keys [:service_plan]

      validates_with NoAdditionalKeysValidator

      validates :service_plan, presence: true, allow_nil: false, to_one_relationship: true

      def service_plan_guid
        HashUtils.dig(service_plan, :data, :guid)
      end
    end
  end
end
