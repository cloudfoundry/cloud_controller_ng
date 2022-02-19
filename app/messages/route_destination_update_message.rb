module VCAP::CloudController
  class RouteDestinationUpdateMessage < BaseMessage
    def initialize(params)
      super(params)
    end

    def self.key_requested?(key)
      proc { |a| a.requested?(key) }
    end

    register_allowed_keys [:protocol]

    validates_with NoAdditionalKeysValidator

    validate :validate_protocol?, if: key_requested?(:protocol)

    private

    def validate_protocol?
      unless protocol.is_a?(String) && RouteMappingModel::VALID_PROTOCOLS.include?(protocol)
        errors.add(:destination, "protocol must be 'http1', 'http2' or 'tcp'.")
      end
    end
  end
end
