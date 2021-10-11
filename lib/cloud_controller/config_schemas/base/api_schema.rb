require 'vcap/config'
require 'cloud_controller/resource_pool'

module VCAP::CloudController
  module ConfigSchemas
    module Base
      class ApiSchema < VCAP::Config
        # rubocop:disable Metrics/BlockLength
        define_schema do
          {
            external_port: Integer,
            external_domain: String,
            temporary_disable_deployments: bool,
            temporary_use_logcache: bool,
            optional(:temporary_disable_v2_staging) => bool,
            tls_port: Integer,
            external_protocol: String,
            internal_service_hostname: String,
            optional(:internal_service_port) => Integer,
            info: {
              name: String,
              build: String,
              version: Integer,
              support_address: String,
              description: String,
              app_ssh_endpoint: String,
              app_ssh_oauth_client: String,
              optional(:min_cli_version) => enum(String, NilClass),
              optional(:min_recommended_cli_version) => enum(String, NilClass),
              optional(:app_ssh_host_key_fingerprint) => String,
              optional(:custom) => Hash,
            },

            system_domain: String,
            optional(:system_domain_organization) => enum(String, NilClass),
            app_domains: Array,
            disable_private_domain_cross_space_context_path_route_sharing: bool,

            default_app_memory: Integer,
            default_app_disk_in_mb: Integer,
            maximum_app_disk_in_mb: Integer,
            default_health_check_timeout: Integer,
            maximum_health_check_timeout: Integer,

            instance_file_descriptor_limit: Integer,

            login: {
              url: String
            },

            uaa: {
              :url => String,
              :resource_id => String,
              :internal_url => String,
              optional(:ca_file) => String,
              :client_timeout => Integer,
              optional(:symmetric_secret) => String,
              optional(:symmetric_secret2) => String,
            },

            logging: {
              level: String, # debug, info, etc.
              file: String, # Log file to use
              syslog: String, # Name to associate with syslog messages (should start with 'vcap.')
              optional(:anonymize_ips) => bool,
              optional(:format) => {
                optional(:timestamp) => String,
              },
            },

            telemetry_log_path: String, # path to log telemetry to, /dev/null to disable

            pid_filename: String, # Pid filename to use

            directories: {
              tmpdir: String,
              diagnostics: String,
            },

            stacks_file: String,
            newrelic_enabled: bool,

            optional(:max_migration_duration_in_minutes) => Integer,
            db: {
              optional(:database) => Hash, # db connection hash for sequel
              max_connections: Integer, # max connections in the connection pool
              pool_timeout: Integer, # timeout before raising an error when connection can't be established to the db
              log_level: String, # debug, info, etc.
              log_db_queries: bool,
              optional(:query_size_log_threshold) => Integer,
              connection_validation_timeout: Integer,
              optional(:connection_expiration_timeout) => Integer,
              optional(:connection_expiration_random_delay) => Integer,
              optional(:ssl_verify_hostname) => bool,
              optional(:ca_cert_path) => String,
            },

            staging: {
              timeout_in_seconds: Integer,
              minimum_staging_memory_mb: Integer,
              minimum_staging_disk_mb: Integer,
              minimum_staging_file_descriptor_limit: Integer,
            },

            index: Integer, # Component index (cc-0, cc-1, etc)
            name: String, # Component name (api_z1, api_z2)
            local_route: String, # If set, use this to determine the IP address that is returned in discovery messages

            nginx: {
              use_nginx: bool,
              instance_socket: String,
            },

            quota_definitions: Hash,
            default_quota_definition: String,

            security_group_definitions: [
              {
                'name' => String,
                'rules' => [
                  {
                    'protocol' => String,
                    'destination' => String,
                    optional('ports') => String,
                    optional('type') => Integer,
                    optional('code') => Integer,
                    optional('log') => bool,
                    optional('description') => String,
                  }
                ]
              }
            ],
            default_staging_security_groups: [String],
            default_running_security_groups: [String],

            resource_pool: {
              maximum_size: Integer,
              minimum_size: Integer,
              resource_directory_key: String,
              fog_connection: Hash,
              fog_aws_storage_options: Hash,
            },

            buildpacks: {
              buildpack_directory_key: String,
              fog_connection: Hash,
              fog_aws_storage_options: Hash,
            },

            packages: {
              max_package_size: Integer,
              max_valid_packages_stored: Integer,
              app_package_directory_key: String,
              fog_connection: Hash,
              fog_aws_storage_options: Hash,
              optional(:image_registry) => {
                base_path: String
              }
            },

            droplets: {
              droplet_directory_key: String,
              max_staged_droplets_stored: Integer,
              fog_connection: Hash,
              fog_aws_storage_options: Hash,
            },

            optional(:registry_buddy) => {
              host: String,
              port: Integer
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
            optional(:uaa_client_name) => String,
            optional(:uaa_client_secret) => String,
            optional(:uaa_client_scope) => String,

            cloud_controller_username_lookup_client_name: String,
            cloud_controller_username_lookup_client_secret: String,

            optional(:credhub_api) => {
              optional(:external_url) => String,
              internal_url: String,
              ca_cert_path: String,
            },

            credential_references: {
              interpolate_service_bindings: bool
            },

            renderer: {
              max_results_per_page: Integer,
              default_results_per_page: Integer,
              max_inline_relations_depth: Integer,
            },

            logcache: {
              host: String,
              port: Integer,
            },

            optional(:logcache_tls) => {
              key_file: String,
              cert_file: String,
              ca_file: String,
              subject_name: String
            },

            optional(:loggregator) => {
              router: String,
              internal_url: String,
            },

            optional(:fluent) => {
              optional(:host) => String,
              optional(:port) => Integer,
            },

            doppler: {
              url: String
            },

            log_cache: {
              url: String
            },

            log_stream: {
              url: String
            },

            request_timeout_in_seconds: Integer,
            threadpool_size: Integer,
            skip_cert_verify: bool,

            install_buildpacks: [
              {
                'name' => String,
                optional('package') => String,
                optional('file') => String,
                optional('enabled') => bool,
                optional('locked') => bool,
                optional('position') => Integer,
              }
            ],

            app_bits_upload_grace_period_in_seconds: Integer,
            allowed_cors_domains: [String],

            optional(:routing_api) => {
              url: String,
              routing_client_name: String,
              routing_client_secret: String,
            },

            route_services_enabled: bool,
            volume_services_enabled: bool,

            optional(:reserved_private_domains) => enum(String, NilClass),

            security_event_logging: {
              enabled: bool,
              file: String,
            },

            bits_service: {
              enabled: bool,
              optional(:public_endpoint) => enum(String, NilClass),
              optional(:private_endpoint) => enum(String, NilClass),
              optional(:username) => enum(String, NilClass),
              optional(:password) => enum(String, NilClass),
            },

            rate_limiter: {
              enabled: bool,
              general_limit: Integer,
              total_general_limit: Integer,
              unauthenticated_limit: Integer,
              total_unauthenticated_limit: Integer,
              reset_interval_in_minutes: Integer,
            },
            shared_isolation_segment_name: String,

            opi: {
              enabled: bool,
              url: String,
              opi_staging: bool,
              cc_uploader_url: String,
              optional(:experimental_enable_crds) => bool,
            },

            allow_app_ssh_access: bool,

            optional(:external_host) => String,

            statsd_host: String,
            statsd_port: Integer,
            system_hostnames: [String],
            default_app_ssh_access: bool,

            jobs: {
              global: { timeout_in_seconds: Integer },
              optional(:app_usage_events_cleanup) => { timeout_in_seconds: Integer },
              optional(:blobstore_delete) => { timeout_in_seconds: Integer },
              optional(:diego_sync) => { timeout_in_seconds: Integer },
            },

            # perm settings no longer have any effect but are preserved here
            # for the time being to avoid breaking users as the perm
            # setting was once required.
            optional(:perm) => {
              optional(:enabled) => bool,
              optional(:hostname) => String,
              optional(:port) => Integer,
              optional(:timeout_in_milliseconds) => Integer,
              optional(:ca_cert_path) => String,
              optional(:query_raise_on_mismatch) => bool,
            },

            optional(:copilot) => {
              enabled: bool,
              optional(:host) => String,
              optional(:port) => Integer,
              optional(:client_ca_file) => String,
              optional(:client_key_file) => String,
              optional(:client_chain_file) => String,
              optional(:temporary_istio_domains) => Array,
            },

            max_labels_per_resource: Integer,
            max_annotations_per_resource: Integer,

            internal_route_vip_range: String,

            default_app_lifecycle: String,
            custom_metric_tag_prefix_list: Array,

            optional(:cc_service_key_client_name) => String,
            optional(:cc_service_key_client_secret) => String,

            optional(:honeycomb) => {
              write_key: String,
              dataset: String,
            },
          }
        end
        # rubocop:enable Metrics/BlockLength

        class << self
          def configure_components(config)
            QuotaDefinition.configure(config)
            PrivateDomain.configure(config.get(:reserved_private_domains))
            ResourcePool.instance = ResourcePool.new(config)
            Stack.configure(config.get(:stacks_file))
          end
        end
      end
    end
  end
end
