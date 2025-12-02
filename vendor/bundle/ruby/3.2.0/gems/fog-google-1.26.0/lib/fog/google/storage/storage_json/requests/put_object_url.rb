module Fog
  module Google
    class StorageJSON
      class Real
        # Get an expiring object url from Google Storage for putting an object
        # https://cloud.google.com/storage/docs/access-control#Signed-URLs
        #
        # @param bucket_name [String] Name of bucket containing object
        # @param object_name [String] Name of object to get expiring url for
        # @param expires [Time] Expiry time for this URL
        # @param headers [Hash] Optional hash of headers to include
        # @option options [String] "x-goog-acl" Permissions, must be in ['private', 'public-read', 'public-read-write', 'authenticated-read'].
        #     If you want a file to be public you should to add { 'x-goog-acl' => 'public-read' } to headers
        #     and then call for example: curl -H "x-goog-acl:public-read" "signed url"
        # @return [String] Expiring object https URL
        def put_object_url(bucket_name, object_name, expires, headers = {})
          raise ArgumentError.new("bucket_name is required") unless bucket_name
          raise ArgumentError.new("object_name is required") unless object_name
          https_url({
                      :headers  => headers,
                      :host     => @host,
                      :method   => "PUT",
                      :path     => "#{bucket_name}/#{object_name}"
                    }, expires)
        end
      end

      class Mock
        def put_object_url(bucket_name, object_name, expires, headers = {})
          raise ArgumentError.new("bucket_name is required") unless bucket_name
          raise ArgumentError.new("object_name is required") unless object_name
          https_url({
                      :headers  => headers,
                      :host     => @host,
                      :method   => "PUT",
                      :path     => "#{bucket_name}/#{object_name}"
                    }, expires)
        end
      end
    end
  end
end
