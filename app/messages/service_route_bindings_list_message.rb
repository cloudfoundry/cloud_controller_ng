require 'messages/list_message'

module VCAP
  module CloudController
    class ServiceRouteBindingsListMessage < ListMessage
      FILTERS = %w[service_instance_guids].freeze

      register_allowed_keys(FILTERS.map(&:to_sym))

      def self.from_params(params)
        super(params, FILTERS)
      end
    end
  end
end
