module VCAP::CloudController
  class ServiceValidator
    def self.validate_auth_token(token, service_handle)
      label = service_handle[:label]
      provider = service_handle[:provider]

      raise Errors::NotAuthorized unless label && provider && token

      svc_auth_token = Models::ServiceAuthToken[
        :label => label,
        :provider => provider,
      ]

      unless svc_auth_token && svc_auth_token.token_matches?(token)
        raise Errors::NotAuthorized
      end

      true
    end
  end
end
