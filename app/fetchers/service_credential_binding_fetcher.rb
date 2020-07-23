module VCAP
  module CloudController
    class ServiceCredentialBindingFetcher
      ServiceInstanceCredential = Struct.new(:guid, :type, :space).freeze

      def fetch(guid)
        ServiceCredentialBinding::View.first(guid: guid).try do |db_binding|
          ServiceInstanceCredential.new(
            db_binding.guid,
            db_binding.type,
            db_binding.space
          )
        end
      end
    end
  end
end
