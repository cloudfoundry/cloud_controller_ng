require 'messages/metadata_base_message'
require 'messages/validators'

module VCAP::CloudController
  class OrganizationQuotasCreateMessage < BaseMessage
    MAX_ORGANIZATION_QUOTA_NAME_LENGTH = 250

    register_allowed_keys [:name, :total_memory_in_mb, :paid_services_allowed, :total_service_instances, :total_routes]
    validates_with NoAdditionalKeysValidator

    validates :name,
      string: true,
      presence: true,
      allow_nil: false,
      length: { maximum: MAX_ORGANIZATION_QUOTA_NAME_LENGTH }

    validates :total_memory_in_mb,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 },
      allow_nil: true

    validates :total_service_instances,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 },
      allow_nil: true

    validates :total_routes,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 },
      allow_nil: true

    validates :paid_services_allowed,
      inclusion: { in: [true, false], message: 'must be a boolean' },
      allow_nil: true
  end
end
