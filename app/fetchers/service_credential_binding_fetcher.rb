require 'fetchers/service_credential_binding_list_fetcher'

module VCAP
  module CloudController
    class ServiceCredentialBindingFetcher
      def fetch(guid, space_guids:)
        list_fetcher.fetch(space_guids: space_guids).first(guid: guid)
      end

      private

      def list_fetcher
        ServiceCredentialBindingListFetcher
      end
    end
  end
end
