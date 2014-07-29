module VCAP::CloudController
  class ServiceAuthTokensController < RestController::ModelController
    define_attributes do
      attribute :label,    String
      attribute :provider, String
      attribute :token,    String
    end

    query_parameters :label, :provider

    def self.translate_validation_exception(e, attributes)
      label_provider_errors = e.errors.on([:label, :provider])
      if label_provider_errors && label_provider_errors.include?(:unique)
        Errors::ApiError.new_from_details("ServiceAuthTokenLabelTaken", "#{attributes["label"]}-#{attributes["provider"]}")
      else
        Errors::ApiError.new_from_details("ServiceAuthTokenInvalid", e.errors.full_messages)
      end
    end

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    define_messages
    define_routes

    deprecated_endpoint '/v2/service_auth_tokens', 'Support for the v1 Service Broker API is deprecated and will be removed in the next major version of Cloud Foundry. Consider upgrading your broker to implement the v2 Service Broker API.'
  end
end
