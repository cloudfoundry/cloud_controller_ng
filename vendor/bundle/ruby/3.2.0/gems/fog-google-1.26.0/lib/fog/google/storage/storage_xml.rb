module Fog
  module Google
    class StorageXML < Fog::Service
      autoload :Mock, "fog/google/storage/storage_xml/mock"
      autoload :Real, "fog/google/storage/storage_xml/real"
      autoload :Utils, "fog/google/storage/storage_xml/utils"

      requires :google_storage_access_key_id, :google_storage_secret_access_key
      recognizes :host, :port, :scheme, :persistent, :path_style

      model_path "fog/google/storage/storage_xml/models"
      collection :directories
      model :directory
      collection :files
      model :file

      request_path "fog/google/storage/storage_xml/requests"
      request :copy_object
      request :delete_bucket
      request :delete_object
      request :delete_object_url
      request :get_bucket
      request :get_bucket_acl
      request :get_object
      request :get_object_acl
      request :get_object_http_url
      request :get_object_https_url
      request :get_object_url
      request :get_service
      request :head_object
      request :put_bucket
      request :put_bucket_acl
      request :put_object
      request :put_object_acl
      request :put_object_url
    end
  end
end
