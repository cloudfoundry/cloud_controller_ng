module Fog
  module Google
    class StorageXML
      class Real
        # Get an expiring object url from Google Storage for deleting an object
        #
        # ==== Parameters
        # * bucket_name<~String> - Name of bucket containing object
        # * object_name<~String> - Name of object to get expiring url for
        # * expires<~Time> - An expiry time for this url
        #
        # ==== Returns
        # * response<~Excon::Response>:
        #   * body<~String> - url for object
        #
        def delete_object_url(bucket_name, object_name, expires)
          raise ArgumentError.new("bucket_name is required") unless bucket_name
          raise ArgumentError.new("object_name is required") unless object_name
          https_url({
                      :headers  => {},
                      :host     => @host,
                      :method   => "DELETE",
                      :path     => "#{bucket_name}/#{object_name}"
                    }, expires)
        end
      end

      class Mock
        def delete_object_url(bucket_name, object_name, expires)
          raise ArgumentError.new("bucket_name is required") unless bucket_name
          raise ArgumentError.new("object_name is required") unless object_name
          https_url({
                      :headers  => {},
                      :host     => @host,
                      :method   => "DELETE",
                      :path     => "#{bucket_name}/#{object_name}"
                    }, expires)
        end
      end
    end
  end
end
