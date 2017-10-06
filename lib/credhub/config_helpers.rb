module Credhub
  module ConfigHelpers
    def encoded_credhub_url
      credhub_url = ::VCAP::CloudController::Config.config.get(:credhub_api, :internal_url)
      return unless credhub_url.present?

      Base64.encode64({ 'credhub-uri' => credhub_url }.to_json)
    end

    def cred_interpolation_enabled?
      ::VCAP::CloudController::Config.config.get(:credential_references, :interpolate_service_bindings)
    end
  end
end
