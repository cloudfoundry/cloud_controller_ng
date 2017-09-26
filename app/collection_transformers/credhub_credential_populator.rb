module VCAP::CloudController
  class CredhubCredentialPopulator
    attr_reader :credhub_client

    def initialize(credhub_client)
      @credhub_client = credhub_client
    end

    def transform(service_keys, _opts={})
      service_keys = Array(service_keys)

      service_keys.each do |service_key|
        if service_key.credhub_reference?
          service_key.credentials = credhub_client.get_credential_by_name(service_key.credhub_reference)
        end
      end
    rescue Credhub::Error
      raise CloudController::Errors::ApiError.new_from_details('ServiceKeyCredentialStoreUnavailable')
    end
  end
end
