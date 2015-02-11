module VCAP::CloudController
  class ServiceAuthTokensController < RestController::ModelController
    DEPRECATION_MESSAGE = [
      'Support for the v1 Service Broker API is deprecated and will re removed in the next major version of Cloud Foundry.',
      'Consider upgrading your broker to implement the v2 Service Broker API.'
    ].join(' ').freeze

    def self.dependencies
      [:service_auth_token_event_repository]
    end

    define_attributes do
      attribute :label,    String
      attribute :provider, String
      attribute :token,    String
    end

    query_parameters :label, :provider

    def inject_dependencies(dependencies)
      super
      @service_auth_token_event_repository = dependencies.fetch(:service_auth_token_event_repository)
    end

    def self.translate_validation_exception(e, attributes)
      label_provider_errors = e.errors.on([:label, :provider])
      if label_provider_errors && label_provider_errors.include?(:unique)
        Errors::ApiError.new_from_details('ServiceAuthTokenLabelTaken', "#{attributes['label']}-#{attributes['provider']}")
      else
        Errors::ApiError.new_from_details('ServiceAuthTokenInvalid', e.errors.full_messages)
      end
    end

    def delete(guid)
      service_auth_token = find_guid_and_validate_access(:delete, guid)
      @service_auth_token_event_repository.record_service_auth_token_delete_request(service_auth_token, SecurityContext.current_user, SecurityContext.current_user_email)
      do_delete(service_auth_token)
    end

    define_messages
    define_routes

    deprecated_endpoint '/v2/service_auth_tokens', DEPRECATION_MESSAGE
  end
end
