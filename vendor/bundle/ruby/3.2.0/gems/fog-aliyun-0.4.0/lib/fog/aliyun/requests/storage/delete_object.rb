# frozen_string_literal: true

module Fog
  module Aliyun
    class Storage
      class Real
        # Delete an existing object
        #
        # ==== Parameters
        # * bucket_name<~String> - Name of bucket to delete
        # * object_name<~String> - Name of object to delete
        #
        def delete_object(bucket_name, object_name, options = {})
          # TODO Support versionId
          # if version_id = options.delete('versionId')
          #   query = {'versionId' => version_id}
          # else
          #   query = {}
          # end
          @oss_http.delete({:bucket => bucket_name, :object => object_name}, {:headers => options})
        end
      end
    end
  end
end
