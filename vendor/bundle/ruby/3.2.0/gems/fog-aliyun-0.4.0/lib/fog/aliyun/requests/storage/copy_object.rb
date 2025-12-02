# frozen_string_literal: true

module Fog
  module Aliyun
    class Storage
      class Real
        # Copy object
        #
        # ==== Parameters
        # * source_bucket_name<~String> - Name of source bucket
        # * source_object_name<~String> - Name of source object
        # * target_bucket_name<~String> - Name of bucket to create copy in
        # * target_object_name<~String> - Name for new copy of object
        # * options<~Hash> - Additional headers options={}
        def copy_object(source_bucket_name, source_object_name, target_bucket_name, target_object_name, options = {})
          headers = { 'x-oss-copy-source' => "/#{source_bucket_name}#{object_to_path(source_object_name)}" }.merge!(options)
          resources = {
              :bucket => target_bucket_name,
              :object => target_object_name
          }
          http_options = {
              :headers => headers
          }
          @oss_http.put(resources, http_options)
        end
      end
    end
  end
end
