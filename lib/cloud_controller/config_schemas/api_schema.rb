require 'vcap/config'

module VCAP::CloudController
  module ConfigSchemas
    class ApiSchema < VCAP::Config
      # rubocop:disable Metrics/BlockLength
      define_schema do
        {
          external_port: Integer,
          external_domain: String,
          temporary_create_internal_domain: bool,
          tls_port: Integer,
          external_protocol: String,
          internal_service_hostname: String,
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
            :ca_file => String,
            optional(:symmetric_secret) => String,
          },

          logging: {
            level: String, # debug, info, etc.
            file: String, # Log file to use
            syslog: String, # Name to associate with syslog messages (should start with 'vcap.')
          },

          pid_filename: String, # Pid filename to use

          directories: {
            tmpdir: String,
            diagnostics: String,
          },

          stacks_file: String,
          newrelic_enabled: bool,

          db: {
            optional(:database) => String, # db connection string for sequel
            max_connections: Integer, # max connections in the connection pool
            pool_timeout: Integer, # timeout before raising an error when connection can't be established to the db
            log_level: String, # debug, info, etc.
            log_db_queries: bool,
            optional(:ssl_verify_hostname) => bool,
            optional(:ca_cert_path) => String,
          },

          bulk_api: {
            auth_user: String,
            auth_password: String,
          },

          internal_api: {
            auth_user: String,
            auth_password: String,
          },

          staging: {
            timeout_in_seconds: Integer,
            minimum_staging_memory_mb: Integer,
            minimum_staging_disk_mb: Integer,
            minimum_staging_file_descriptor_limit: Integer,
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
          },

          droplets: {
            droplet_directory_key: String,
            max_staged_droplets_stored: Integer,
            fog_connection: Hash,
            fog_aws_storage_options: Hash,
          },

          db_encryption_key: enum(String, NilClass),

          optional(:database_encryption) => {
              keys: Hash,
              current_key_label: String
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

          cc_service_key_client_name: String,
          cc_service_key_client_secret: String,

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

          loggregator: {
            router: String,
            internal_url: String,
          },

          doppler: {
            url: String
          },

          request_timeout_in_seconds: Integer,
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

          :bits_service => {
            enabled: bool,
            optional(:public_endpoint) => enum(String, NilClass),
            optional(:private_endpoint) => enum(String, NilClass),
            optional(:username) => enum(String, NilClass),
            optional(:password) => enum(String, NilClass),
          },

          rate_limiter: {
            enabled: bool,
            general_limit: Integer,
            unauthenticated_limit: Integer,
            reset_interval_in_minutes: Integer,
          },
          shared_isolation_segment_name: String,

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
            insecure_docker_registry_list: [String],
            docker_staging_stack: String,
            optional(:temporary_oci_buildpack_mode) => enum('oci-phase-1', NilClass),
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

          perm: {
            query_enabled: bool,
            enabled: bool,
            optional(:hostname) => String,
            optional(:port) => Integer,
            timeout_in_milliseconds: Integer,
            ca_cert_path: String,
            optional(:query_raise_on_mismatch) => bool,
          }
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
