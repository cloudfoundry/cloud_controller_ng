require 'vcap/config'

module VCAP::CloudController
  module ConfigSchemas
    class ClockSchema < VCAP::Config
      # rubocop:disable Metrics/BlockLength
      define_schema do
        {
          external_port: Integer,
          external_domain: String,
          tls_port: Integer,
          external_protocol: String,
          internal_service_hostname: String,

          app_usage_events: {
            cutoff_age_in_days: Integer
          },
          audit_events: {
            cutoff_age_in_days: Integer
          },
          failed_jobs: {
            cutoff_age_in_days: Integer
          },
          completed_tasks: {
            cutoff_age_in_days: Integer
          },
          default_health_check_timeout: Integer,

          uaa: {
            internal_url: String,
            ca_file: String,
          },

          logging: {
            level: String, # debug, info, etc.
            file: String, # Log file to use
            syslog: String, # Name to associate with syslog messages (should start with 'vcap.')
          },

          pid_filename: String, # Pid filename to use

          newrelic_enabled: bool,

          db: {
            optional(:database) => String, # db connection string for sequel
            :max_connections => Integer, # max connections in the connection pool
            :pool_timeout => Integer, # timeout before raising an error when connection can't be established to the db
            :log_level => String, # debug, info, etc.
            :ssl_verify_hostname => bool,
            optional(:ca_cert_path) => String,
          },

          internal_api: {
            auth_user: String,
            auth_password: String,
          },

          staging: {
            timeout_in_seconds: Integer,
            auth: {
              user: String,
              password: String,
            }
          },

          index: Integer, # Component index (cc-0, cc-1, etc)
          name: String, # Component name (api_z1, api_z2)
          local_route: String, # If set, use this to determine the IP address that is returned in discovery messages

          nginx: {
            use_nginx: bool,
            instance_socket: String,
          },

          resource_pool: {
            maximum_size: Integer,
            minimum_size: Integer,
            resource_directory_key: String,
            fog_connection: Hash,
            fog_aws_storage_options: Hash
          },

          buildpacks: {
            buildpack_directory_key: String,
            fog_connection: Hash,
            fog_aws_storage_options: Hash
          },

          packages: {
            max_package_size: Integer,
            app_package_directory_key: String,
            fog_connection: Hash,
            fog_aws_storage_options: Hash
          },

          droplets: {
            droplet_directory_key: String,
            fog_connection: Hash,
            fog_aws_storage_options: Hash
          },

          db_encryption_key: String,

          optional(:database_encryption_keys) => {
              keys: Hash,
              current_key_label: String
          },

          uaa_client_name: String,
          uaa_client_secret: String,
          uaa_client_scope: String,

          loggregator: {
            router: String,
          },

          skip_cert_verify: bool,

          optional(:routing_api) => {
            url: String,
            routing_client_name: String,
            routing_client_secret: String,
          },

          optional(:bits_service) => {
            enabled: bool,
            optional(:public_endpoint) => enum(String, NilClass),
            optional(:private_endpoint) => enum(String, NilClass),
            optional(:username) => enum(String, NilClass),
            optional(:password) => enum(String, NilClass),
          },

          diego: {
            bbs: {
              url: String,
              ca_file: String,
              cert_file: String,
              key_file: String,
            },
            cc_uploader_url: String,
            file_server_url: String,
            lifecycle_bundles: Hash,
            nsync_url: String,
            pid_limit: Integer,
            stager_url: String,
            temporary_local_staging: bool,
            temporary_local_tasks: bool,
            temporary_local_apps: bool,
            temporary_local_sync: bool,
            temporary_local_tps: bool,
            temporary_cc_uploader_mtls: bool,
            temporary_droplet_download_mtls: bool,
            tps_url: String,
            use_privileged_containers_for_running: bool,
            use_privileged_containers_for_staging: bool,
            optional(:temporary_oci_buildpack_mode) => enum('oci-phase-1', NilClass),
          },

          development_mode: bool,

          default_app_memory: Integer,
          default_app_disk_in_mb: Integer,
          instance_file_descriptor_limit: Integer,
          maximum_app_disk_in_mb: Integer,

          diego_sync: { frequency_in_seconds: Integer },

          pending_builds: {
            expiration_in_seconds: Integer,
            frequency_in_seconds: Integer,
          },
          pending_droplets: {
            expiration_in_seconds: Integer,
            frequency_in_seconds: Integer,
          },

          service_usage_events: { cutoff_age_in_days: Integer },
          default_app_ssh_access: bool,
          allow_app_ssh_access: bool,
          jobs: {
            global: { timeout_in_seconds: Integer },
            optional(:app_usage_events_cleanup) => { timeout_in_seconds: Integer },
            optional(:blobstore_delete) => { timeout_in_seconds: Integer },
            optional(:diego_sync) => { timeout_in_seconds: Integer },
          }
        }
      end
      # rubocop:enable Metrics/BlockLength

      class << self
        def configure_components(config); end
      end
    end
  end
end
