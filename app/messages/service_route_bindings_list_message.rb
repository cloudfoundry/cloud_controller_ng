require 'messages/list_message'

module VCAP
  module CloudController
    class ServiceRouteBindingsListMessage < ListMessage
      QUERY_PARAMS = %w[
        service_instance_guids
        service_instance_names
        route_guids
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
