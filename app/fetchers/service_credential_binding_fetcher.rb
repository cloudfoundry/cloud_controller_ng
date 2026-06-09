require 'fetchers/service_credential_binding_list_fetcher'

module VCAP
  module CloudController
    class ServiceCredentialBindingFetcher
      def fetch(guid, readable_space_ids_query: nil)
        list_fetcher.fetch(readable_space_ids_query:).first(guid:)
      end

      private

      def list_fetcher
        ServiceCredentialBindingListFetcher
      end
    end
  end
end
