# frozen_string_literal: true

module Fog
  module Aliyun
    class Storage
      class Real
        # Get headers for object
        #
        # ==== Parameters
        # * object_name<~String> - Name of object to look for
        #
        def head_object(bucket_name, object_name, options={})
          unless bucket_name
            raise ArgumentError.new('bucket_name is required')
          end
          unless object_name
            raise ArgumentError.new('object_name is required')
          end

          # Currently, the ruby sdk does not support versionId
          # if version_id = options.delete('versionId')
          #   query = {'versionId' => version_id}
          # end
          headers = {}
          headers['If-Modified-Since'] = Fog::Time.at(options['If-Modified-Since'].to_i).to_date_header if options['If-Modified-Since']
          headers['If-Unmodified-Since'] = Fog::Time.at(options['If-Unmodified-Since'].to_i).to_date_header if options['If-Modified-Since']
          headers.merge!(options)
          resources = {
              :bucket => bucket_name,
              :object => object_name
          }
          http_options = {
              :headers => headers
          }
          @oss_http.head(resources, http_options)
        end
      end
    end
  end
end
