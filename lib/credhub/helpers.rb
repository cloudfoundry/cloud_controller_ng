module Credhub
  module Helpers
    def encoded_credhub_url
      credhub_url = ::VCAP::CloudController::Config.config.get(:credhub_api, :internal_url)
      return unless credhub_url.present?

      Base64.encode64({ 'credhub-uri' => credhub_url }.to_json)
    end
  end
end
