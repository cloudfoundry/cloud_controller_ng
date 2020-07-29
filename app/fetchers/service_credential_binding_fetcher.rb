module VCAP
  module CloudController
    class ServiceCredentialBindingFetcher
      ServiceInstanceCredential = Struct.new(:guid, :type).freeze

      def fetch(guid, space_guids:)
        list_fetcher.fetch(space_guids: space_guids).first(guid: guid).try do |db_binding|
          ServiceInstanceCredential.new(
            db_binding.guid,
            db_binding.type
          )
        end
      end

      private

      def list_fetcher
        ServiceCredentialBindingListFetcher.new
      end
    end
  end
end
