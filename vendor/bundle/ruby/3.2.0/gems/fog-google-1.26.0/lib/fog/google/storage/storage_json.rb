module Fog
  module Google
    class StorageJSON < Fog::Service
      autoload :Mock, "fog/google/storage/storage_json/mock"
      autoload :Real, "fog/google/storage/storage_json/real"
      autoload :Utils, "fog/google/storage/storage_json/utils"

      requires :google_project
      recognizes(
        :app_name,
        :app_version,
        :google_application_default,
        :google_auth,
        :google_client,
        :google_client_options,
        :google_key_location,
        :google_key_string,
        :google_json_key_location,
        :google_json_key_string,
        :open_timeout_sec,
        :read_timeout_sec,
        :send_timeout_sec
      )

      # https://cloud.google.com/storage/docs/json_api/v1/
      GOOGLE_STORAGE_JSON_API_VERSION = "v1".freeze
      GOOGLE_STORAGE_JSON_BASE_URL = "https://www.googleapis.com/storage/".freeze
      GOOGLE_STORAGE_BUCKET_BASE_URL = "https://storage.googleapis.com/".freeze

      # Version of IAM API used for blob signing, see Fog::Google::StorageJSON::Real#iam_signer
      GOOGLE_STORAGE_JSON_IAM_API_VERSION = "v1".freeze
      GOOGLE_STORAGE_JSON_IAM_API_SCOPE_URLS = %w(https://www.googleapis.com/auth/iam).freeze

      # TODO: Come up with a way to only request a subset of permissions.
      # https://cloud.google.com/storage/docs/json_api/v1/how-tos/authorizing
      GOOGLE_STORAGE_JSON_API_SCOPE_URLS = %w(https://www.googleapis.com/auth/devstorage.full_control).freeze

      ##
      # Models
      model_path "fog/google/storage/storage_json/models"

      collection :directories
      model :directory

      collection :files
      model :file

      ##
      # Requests
      request_path "fog/google/storage/storage_json/requests"
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
      request :get_object_metadata
      request :get_object_url
      request :list_buckets
      request :list_bucket_acl
      request :list_objects
      request :list_object_acl
      request :put_bucket
      request :put_bucket_acl
      request :put_object
      request :put_object_acl
      request :put_object_url
    end
  end
end
