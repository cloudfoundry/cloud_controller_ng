module VCAP
  module CloudController
    class ServiceCredentialBindingFetcher
      def fetch(guid, space_guids:)
        list_fetcher.fetch(space_guids: space_guids).first(guid: guid)
      end

      private

      def list_fetcher
        ServiceCredentialBindingListFetcher.new
      end
    end
  end
end
