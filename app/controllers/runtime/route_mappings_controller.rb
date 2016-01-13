module VCAP::CloudController
  class RouteMappingsController < RestController::ModelController
    define_attributes do
      to_one :app, exclude_in: [:update]
      to_one :route, exclude_in: [:update]
      attribute :app_port, Integer, default: nil
    end

    post path, :create

    def self.translate_validation_exception(e, attributes)
      port_errors = e.errors.on(:app_port)
      if port_errors && port_errors.include?(:diego_only)
        Errors::ApiError.new_from_details('AppPortMappingRequiresDiego')
      elsif port_errors && port_errors.include?(:not_bound_to_app)
        Errors::ApiError.new_from_details('RoutePortNotEnabledOnApp')
      end
    end

    define_messages
  end
end
