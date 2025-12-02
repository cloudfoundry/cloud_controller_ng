module Fog
  module Google
    class SQL < Fog::Service
      autoload :Mock, File.expand_path("../sql/mock", __FILE__)
      autoload :Real, File.expand_path("../sql/real", __FILE__)

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
        :google_json_key_string
      )

      GOOGLE_SQL_API_VERSION    = "v1beta4".freeze
      GOOGLE_SQL_BASE_URL       = "https://www.googleapis.com/sql/".freeze
      GOOGLE_SQL_API_SCOPE_URLS = %w(https://www.googleapis.com/auth/sqlservice.admin
                                     https://www.googleapis.com/auth/cloud-platform).freeze

      ##
      # MODELS
      model_path "fog/google/models/sql"

      # Backup Run
      model :backup_run
      collection :backup_runs

      # Flag
      model :flag
      collection :flags

      # Instance
      model :instance
      collection :instances

      # Operation
      model :operation
      collection :operations

      # SSL Certificate
      model :ssl_cert
      collection :ssl_certs

      # Tier
      model :tier
      collection :tiers

      # User
      model :user
      collection :users

      ##
      # REQUESTS
      request_path "fog/google/requests/sql"

      # Backup Run
      request :delete_backup_run
      request :get_backup_run
      request :insert_backup_run
      request :list_backup_runs

      # Flag
      request :list_flags

      # Instance
      request :clone_instance
      request :delete_instance
      request :export_instance
      request :get_instance
      request :import_instance
      request :insert_instance
      request :list_instances
      request :reset_instance_ssl_config
      request :restart_instance
      request :restore_instance_backup
      request :update_instance

      # Operation
      request :get_operation
      request :list_operations

      # SSL Certificate
      request :delete_ssl_cert
      request :get_ssl_cert
      request :insert_ssl_cert
      request :list_ssl_certs

      # Tier
      request :list_tiers

      # User
      request :insert_user
      request :update_user
      request :list_users
      request :delete_user
    end
  end
end
