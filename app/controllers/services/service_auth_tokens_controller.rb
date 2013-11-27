module VCAP::CloudController
  class ServiceAuthTokensController < RestController::ModelController
    define_attributes do
      attribute :label,    String
      attribute :provider, String
      attribute :token,    String,  :exclude_in => :response
    end

    query_parameters :label, :provider

    def self.translate_validation_exception(e, attributes)
      label_provider_errors = e.errors.on([:label, :provider])
      if label_provider_errors && label_provider_errors.include?(:unique)
        Errors::ServiceAuthTokenLabelTaken.new("#{attributes["label"]}-#{attributes["provider"]}")
      else
        Errors::ServiceAuthTokenInvalid.new(e.errors.full_messages)
      end
    end

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    define_messages
    define_routes
  end
end
