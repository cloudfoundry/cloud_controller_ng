module Fog
  module Google
    class StorageJSON
      class Real
        # Lists objects in a bucket matching some criteria.
        #
        # @param bucket [String] Name of bucket to list
        # @param options [Hash] Optional hash of options
        # @option options [String] :delimiter Delimiter to collapse objects
        #   under to emulate a directory-like mode
        # @option options [Integer] :max_results Maximum number of results to
        #   retrieve
        # @option options [String] :page_token Token to select a particular page
        #   of results
        # @option options [String] :prefix String that an object must begin with
        #   in order to be returned
        # @option options ["full", "noAcl"] :projection Set of properties to
        #   return (defaults to "noAcl")
        # @option options [Boolean] :versions If true, lists all versions of an
        #   object as distinct results (defaults to False)
        # @return [Google::Apis::StorageV1::Objects]
        def list_objects(bucket, options = {})
          allowed_opts = %i(
            delimiter
            max_results
            page_token
            prefix
            projection
            versions
          )

          @storage_json.list_objects(
            bucket,
            **options.select { |k, _| allowed_opts.include? k }
          )
        end
      end

      class Mock
        def list_objects(_bucket, _options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
