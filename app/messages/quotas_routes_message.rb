require 'messages/metadata_base_message'
require 'messages/validators'

module VCAP::CloudController
  class QuotasRoutesMessage < BaseMessage
    register_allowed_keys [:total_routes, :total_reserved_ports]

    validates_with NoAdditionalKeysValidator

    validates :total_routes,
      numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_DB_INT },
      allow_nil: true

    validates :total_reserved_ports,
      numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_DB_INT },
      allow_nil: true
  end
end
