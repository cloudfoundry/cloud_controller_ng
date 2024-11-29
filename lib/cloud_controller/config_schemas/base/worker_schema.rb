require 'vcap/config'

module VCAP::CloudController
  module ConfigSchemas
    module Base
      class WorkerSchema < VCAP::Config
        # rubocop:disable Metrics/BlockLength
        define_schema do
          {
            external_port: Integer,
            external_domain: String,
            system_hostnames: [String],
            system_domain: String,
            tls_port: Integer,
            external_protocol: String,
            internal_service_hostname: String,
            disable_private_domain_cross_space_context_path_route_sharing: bool,
            readiness_port: {
              cloud_controller_worker: Integer
            },
            default_health_check_timeout: Integer,
            maximum_health_check_timeout: Integer,

            optional(:temporary_enable_v2) => bool,

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

            log_audit_events: bool,

            stacks_file: String,
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
              timeout_in_seconds: Integer
            },

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
              fog_aws_storage_options: Hash,
              fog_gcp_storage_options: Hash
            },

            buildpacks: {
              buildpack_directory_key: String,
              fog_connection: Hash,
              fog_aws_storage_options: Hash,
              fog_gcp_storage_options: Hash
            },

            packages: {
              max_package_size: Integer,
              max_valid_packages_stored: Integer,
              app_package_directory_key: String,
              fog_connection: Hash,
              fog_aws_storage_options: Hash,
              fog_gcp_storage_options: Hash
            },

            droplets: {
              droplet_directory_key: String,
              fog_connection: Hash,
              fog_aws_storage_options: Hash,
              fog_gcp_storage_options: Hash
            },

            db_encryption_key: enum(String, NilClass),

            optional(:database_encryption) => {
              keys: Hash,
              current_key_label: String,
              optional(:pbkdf2_hmac_iterations) => Integer
            },

            disable_custom_buildpacks: bool,

            broker_client_timeout_seconds: Integer,
            broker_client_default_async_poll_interval_seconds: Integer,
            broker_client_max_async_poll_duration_minutes: Integer,
            broker_client_async_poll_exponential_backoff_rate: Numeric,
            optional(:broker_client_response_parser) => {
              log_errors: bool,
              log_validators: bool,
              log_response_fields: Hash
            },
            optional(:uaa_client_name) => String,
            optional(:uaa_client_secret) => String,
            optional(:uaa_client_scope) => String,

            optional(:cc_service_key_client_name) => String,

            optional(:credhub_api) => {
              internal_url: String
            },

            credential_references: {
              interpolate_service_bindings: bool
            },

            optional(:loggregator) => {
              router: String
            },

            optional(:fluent) => {
              optional(:host) => String,
              optional(:port) => Integer
            },

            skip_cert_verify: bool,

            optional(:routing_api) => {
              url: String,
              routing_client_name: String,
              routing_client_secret: String
            },

            allow_app_ssh_access: bool,

            perform_blob_cleanup: bool,

            cpu_weight_min_memory: Integer,
            cpu_weight_max_memory: Integer,
            default_app_memory: Integer,
            default_app_disk_in_mb: Integer,
            instance_file_descriptor_limit: Integer,
            maximum_app_disk_in_mb: Integer,
            default_app_log_rate_limit_in_bytes_per_second: Integer,
            default_app_ssh_access: bool,

            jobs: {
              global: { timeout_in_seconds: Integer },
              queues: {
                optional(:cc_generic) => { timeout_in_seconds: Integer }
              },
              optional(:enable_dynamic_job_priorities) => bool,
              optional(:app_usage_events_cleanup) => { timeout_in_seconds: Integer },
              optional(:blobstore_delete) => { timeout_in_seconds: Integer },
              optional(:diego_sync) => { timeout_in_seconds: Integer },
              optional(:priorities) => Hash
            },

            volume_services_enabled: bool,
            route_services_enabled: bool,

            max_manifest_service_binding_poll_duration_in_seconds: Integer,

            max_labels_per_resource: Integer,
            max_annotations_per_resource: Integer,
            internal_route_vip_range: String,
            custom_metric_tag_prefix_list: Array
          }
        end
        # rubocop:enable Metrics/BlockLength

        class << self
          def configure_components(config)
            ResourcePool.instance = ResourcePool.new(config)
            Stack.configure(config.get(:stacks_file))
          end
        end
      end
    end
  end
end
