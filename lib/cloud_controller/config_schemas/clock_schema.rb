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
          readiness_port: {
            clock: Integer
          },
          app_usage_events: {
            cutoff_age_in_days: Integer
          },
          audit_events: {
            cutoff_age_in_days: Integer
          },
          failed_jobs: {
            cutoff_age_in_days: Integer,
            optional(:max_number_of_failed_delayed_jobs) => Integer,
            frequency_in_seconds: Integer
          },
          pollable_jobs: {
            cutoff_age_in_days: Integer
          },
          service_operations_initial_cleanup: {
            frequency_in_seconds: Integer
          },
          completed_tasks: {
            cutoff_age_in_days: Integer
          },
          default_health_check_timeout: Integer,

          uaa: {
            internal_url: String,
            optional(:ca_file) => String,
            client_timeout: Integer
          },

          logging: {
            level: String, # debug, info, etc.
            file: String, # Log file to use
            syslog: String # Name to associate with syslog messages (should start with 'vcap.')
          },

          pid_filename: String, # Pid filename to use

          optional(:storage_cli_config_file_buildpacks) => String,
          optional(:storage_cli_config_file_packages) => String,
          optional(:storage_cli_config_file_resource_pool) => String,
          optional(:storage_cli_config_file_droplets) => String,
          optional(:storage_cli_optional_flags) => String,

          newrelic_enabled: bool,

          optional(:max_migration_duration_in_minutes) => Integer,
          db: {
            optional(:database) => Hash, # db connection hash for sequel
            max_connections: Integer, # max connections in the connection pool
            pool_timeout: Integer, # timeout before raising an error when connection can't be established to the db
            log_level: String, # debug, info, etc.
            log_db_queries: bool,
            ssl_verify_hostname: bool,
            connection_validation_timeout: Integer,
            optional(:ca_cert_path) => String
          },

          staging: {
            auth: {
              user: String,
              password: String
            },
            timeout_in_seconds: Integer
          },

          diego: {
            bbs: {
              url: String,
              ca_file: String,
              cert_file: String,
              key_file: String,
              connect_timeout: Integer,
              send_timeout: Integer,
              receive_timeout: Integer
            },
            cc_uploader_url: String,
            file_server_url: String,
            lifecycle_bundles: Hash,
            droplet_destinations: Hash,
            pid_limit: Integer,
            use_privileged_containers_for_running: bool,
            use_privileged_containers_for_staging: bool,
            optional(:temporary_oci_buildpack_mode) => enum('oci-phase-1', NilClass),
            enable_declarative_asset_downloads: bool
          },

          app_log_revision: bool,

          index: Integer, # Component index (cc-0, cc-1, etc)
          name: String, # Component name (api_z1, api_z2)
          local_route: String, # If set, use this to determine the IP address that is returned in discovery messages

          nginx: {
            use_nginx: bool,
            instance_socket: String
          },

          resource_pool: {
            maximum_size: Integer,
            minimum_size: Integer,
            resource_directory_key: String,
            fog_connection: Hash,
            optional(:connection_config) => Hash,
            fog_aws_storage_options: Hash,
            fog_gcp_storage_options: Hash
          },

          buildpacks: {
            buildpack_directory_key: String,
            fog_connection: Hash,
            optional(:connection_config) => Hash,
            fog_aws_storage_options: Hash,
            fog_gcp_storage_options: Hash
          },

          packages: {
            max_package_size: Integer,
            app_package_directory_key: String,
            fog_connection: Hash,
            optional(:connection_config) => Hash,
            fog_aws_storage_options: Hash,
            fog_gcp_storage_options: Hash
          },

          droplets: {
            droplet_directory_key: String,
            fog_connection: Hash,
            optional(:connection_config) => Hash,
            fog_aws_storage_options: Hash,
            fog_gcp_storage_options: Hash
          },

          db_encryption_key: enum(String, NilClass),

          optional(:database_encryption) => {
            keys: Hash,
            current_key_label: String,
            optional(:pbkdf2_hmac_iterations) => Integer
          },

          optional(:uaa_client_name) => String,
          optional(:uaa_client_secret) => String,
          optional(:uaa_client_scope) => String,

          optional(:loggregator) => {
            router: String
          },

          optional(:fluent) => {
            optional(:host) => String,
            optional(:port) => Integer
          },

          optional(:publish_metrics) => bool,
          optional(:prometheus_port) => Integer,

          skip_cert_verify: bool,

          optional(:routing_api) => {
            url: String,
            routing_client_name: String,
            routing_client_secret: String
          },

          optional(:credhub_api) => {
            internal_url: String,
            ca_cert_path: String
          },

          credential_references: {
            interpolate_service_bindings: bool
          },

          cpu_weight_min_memory: Integer,
          cpu_weight_max_memory: Integer,
          default_app_memory: Integer,
          default_app_disk_in_mb: Integer,
          default_app_log_rate_limit_in_bytes_per_second: Integer,
          instance_file_descriptor_limit: Integer,
          maximum_app_disk_in_mb: Integer,
          max_retained_deployments_per_app: Integer,
          max_retained_builds_per_app: Integer,
          max_retained_revisions_per_app: Integer,
          additional_allowed_process_users: Array,
          allow_docker_root_user: bool,

          diego_sync: { frequency_in_seconds: Integer },

          pending_builds: {
            expiration_in_seconds: Integer,
            frequency_in_seconds: Integer
          },
          pending_droplets: {
            expiration_in_seconds: Integer,
            frequency_in_seconds: Integer
          },

          service_usage_events: { cutoff_age_in_days: Integer },
          app_usage_snapshot: { cutoff_age_in_days: Integer },
          service_usage_snapshot: { cutoff_age_in_days: Integer },
          default_app_ssh_access: bool,
          allow_app_ssh_access: bool,
          jobs: {
            global: { timeout_in_seconds: Integer },
            optional(:read_ahead) => Integer,
            optional(:app_usage_events_cleanup) => { timeout_in_seconds: Integer },
            optional(:blobstore_delete) => { timeout_in_seconds: Integer },
            optional(:diego_sync) => { timeout_in_seconds: Integer },
            optional(:priorities) => Hash
          },

          statsd_host: String,
          statsd_port: Integer,
          optional(:enable_statsd_metrics) => bool,

          max_labels_per_resource: Integer,
          max_annotations_per_resource: Integer,
          custom_metric_tag_prefix_list: Array,

          optional(:feature_flag_overrides) => Hash
        }
      end
      # rubocop:enable Metrics/BlockLength

      class << self
        def configure_components(config); end
      end
    end
  end
end
