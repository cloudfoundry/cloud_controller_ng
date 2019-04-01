module Credhub
  module ConfigHelpers
    def credhub_url
      credhub_url = ::VCAP::CloudController::Config.config.get(:credhub_api, :internal_url)
      return unless credhub_url.present?

      "{\"credhub-uri\":\"#{credhub_url}\"}"
    end

    def cred_interpolation_enabled?
      ::VCAP::CloudController::Config.config.get(:credential_references, :interpolate_service_bindings)
    end
  end
end
