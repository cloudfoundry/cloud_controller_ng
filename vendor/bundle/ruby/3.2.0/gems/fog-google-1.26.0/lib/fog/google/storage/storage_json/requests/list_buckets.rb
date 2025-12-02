module Fog
  module Google
    class StorageJSON
      class Real
        # Retrieves a list of buckets for a given project
        # https://cloud.google.com/storage/docs/json_api/v1/buckets/list
        #
        # @return [Google::Apis::StorageV1::Buckets]
        # TODO: check if very large lists require working with nextPageToken
        def list_buckets(max_results: nil, page_token: nil,
                         prefix: nil, projection: nil)
          @storage_json.list_buckets(
            @project,
            max_results: max_results,
            page_token: page_token,
            prefix: prefix,
            projection: projection
          )
        end
      end
      class Mock
        def list_buckets
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
