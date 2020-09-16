require 'messages/list_message'

module VCAP
  module CloudController
    class ServiceRouteBindingShowMessage < BaseMessage
      QUERY_PARAMS = %w[
        include
      ].freeze

      register_allowed_keys QUERY_PARAMS.map(&:to_sym)

      validates_with IncludeParamValidator, valid_values: %w(route service_instance)

      def self.from_params(params)
        super(params, QUERY_PARAMS)
      end
    end
  end
end
