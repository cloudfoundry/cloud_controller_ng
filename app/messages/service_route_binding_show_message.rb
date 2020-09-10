require 'messages/list_message'

module VCAP
  module CloudController
    class ServiceRouteBindingShowMessage < BaseMessage
      QUERY_PARAMS = %w[
        include
      ].freeze

      register_allowed_keys QUERY_PARAMS.map(&:to_sym)

      def self.from_params(params)
        super(params, QUERY_PARAMS)
      end
    end
  end
end
