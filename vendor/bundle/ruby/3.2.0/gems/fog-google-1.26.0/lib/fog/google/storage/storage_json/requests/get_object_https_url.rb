module Fog
  module Google
    class StorageJSON
      module GetObjectHttpsUrl
        def get_object_https_url(bucket_name, object_name, expires, options = {})
          raise ArgumentError.new("bucket_name is required") unless bucket_name
          raise ArgumentError.new("object_name is required") unless object_name

          https_url(options.merge(:headers  => {},
                                  :host     => @host,
                                  :method   => "GET",
                                  :path     => "#{bucket_name}/#{object_name}"),
                    expires)
        end
      end

      class Real
        # Get an expiring object https url from Google Storage
        # https://cloud.google.com/storage/docs/access-control#Signed-URLs
        #
        # @param bucket_name [String] Name of bucket to read from
        # @param object_name [String] Name of object to read
        # @param expires [Time] Expiry time for this URL
        # @return [String] Expiring object https URL
        include GetObjectHttpsUrl
      end

      class Mock # :nodoc:all
        include GetObjectHttpsUrl
      end
    end
  end
end
