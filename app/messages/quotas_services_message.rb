require 'messages/metadata_base_message'
require 'messages/validators'

module VCAP::CloudController
  class QuotasServicesMessage < BaseMessage
    register_allowed_keys [:total_service_instances, :total_service_keys, :paid_services_allowed]

    validates_with NoAdditionalKeysValidator

    validates :total_service_keys,
      numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_DB_INT },
      allow_nil: true

    validates :total_service_instances,
      numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_DB_INT },
      allow_nil: true

    validates :paid_services_allowed,
      inclusion: { in: [true, false], message: 'must be a boolean' },
      allow_nil: true
  end
end
