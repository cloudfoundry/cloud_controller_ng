require 'fetchers/service_credential_binding_list_fetcher'

module VCAP
  module CloudController
    class ServiceCredentialBindingFetcher
      def fetch(guid, readable_spaces_query: nil)
        list_fetcher.fetch(readable_spaces_query: readable_spaces_query).first(guid: guid)
      end

      private

      def list_fetcher
        ServiceCredentialBindingListFetcher
      end
    end
  end
end
