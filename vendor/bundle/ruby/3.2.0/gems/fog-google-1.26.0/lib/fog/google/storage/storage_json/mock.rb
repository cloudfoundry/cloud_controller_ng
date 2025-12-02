module Fog
  module Google
    class StorageJSON
      class Mock
        include Utils
        include Fog::Google::Shared

        MockClient = Struct.new(:issuer)

        def initialize(options = {})
          shared_initialize(options[:google_project], GOOGLE_STORAGE_JSON_API_VERSION, GOOGLE_STORAGE_JSON_BASE_URL)
          @client = MockClient.new('test')
          @storage_json = MockClient.new('test')
          @iam_service = MockClient.new('test')
        end

        def signature(_params)
          "foo"
        end

        def google_access_id
          "my-account@project.iam.gserviceaccount"
        end
      end
    end
  end
end
