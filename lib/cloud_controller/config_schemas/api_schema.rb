require 'vcap/config'

module VCAP::CloudController
  module ConfigSchemas
    class ApiSchema < VCAP::Config
      # rubocop:disable Metrics/BlockLength
      define_schema do
        {
          :external_port => Integer,
          :external_domain => String,
          :tls_port => Integer,
          :external_protocol => String,
          :internal_service_hostname => String,
          :info => {
            name: String,
            build: String,
            version: Integer,
            support_address: String,
            description: String,
            optional(:app_ssh_endpoint) => String,
            optional(:app_ssh_host_key_fingerprint) => String,
            optional(:app_ssh_oauth_client) => String,
            optional(:min_cli_version) => String,
            optional(:min_recommended_cli_version) => String,
            optional(:custom) => Hash,
          },

          :system_domain => String,
          :system_domain_organization => enum(String, NilClass),
          :app_domains => Array,
          :app_usage_events => {
            cutoff_age_in_days: Integer
          },
          :audit_events => {
            cutoff_age_in_days: Integer
          },
          :failed_jobs => {
            cutoff_age_in_days: Integer
          },
          :completed_tasks => {
            cutoff_age_in_days: Integer
          },
          :default_app_memory => Integer,
          :default_app_disk_in_mb => Integer,
          optional(:maximum_app_disk_in_mb) => Integer,
          :default_health_check_timeout => Integer,
          :maximum_health_check_timeout => Integer,

          optional(:instance_file_descriptor_limit) => Integer,

          optional(:bits_service) => {
            enabled: bool,
          },

          optional(:login) => {
            url: String
          },

          :uaa => {
            :url => String,
            :resource_id => String,
            optional(:symmetric_secret) => String,
            :internal_url => String,
            :ca_file => String,
          },

          :logging => {
            :level => String, # debug, info, etc.
            optional(:file) => String, # Log file to use
            optional(:syslog) => String, # Name to associate with syslog messages (should start with 'vcap.')
          },

          :pid_filename => String, # Pid filename to use

          optional(:directories) => {
            optional(:tmpdir) => String,
            optional(:diagnostics) => String,
          },

          optional(:stacks_file) => String,
          optional(:newrelic_enabled) => bool,
          optional(:hostname) => String,

          optional(:db) => {
            optional(:database) => String, # db connection string for sequel
            optional(:log_level) => String, # debug, info, etc.
            optional(:max_connections) => Integer, # max connections in the connection pool
            optional(:pool_timeout) => Integer # timeout before raising an error when connection can't be established to the db
          },

          :bulk_api => {
            auth_user: String,
            auth_password: String,
          },

          :internal_api => {
            auth_user: String,
            auth_password: String,
          },

          :staging => {
            :timeout_in_seconds => Integer,
            optional(:minimum_staging_memory_mb) => Integer,
            optional(:minimum_staging_disk_mb) => Integer,
            optional(:minimum_staging_file_descriptor_limit) => Integer,
            :auth => {
              user: String,
              password: String,
            }
          },

          optional(:default_account_capacity) => {
            memory: Integer, #:default => 2048,
            app_uris: Integer, #:default => 4,
            services: Integer, #:default => 16,
            apps: Integer, #:default => 20
          },

          optional(:admin_account_capacity) => {
            memory: Integer, #:default => 2048,
            app_uris: Integer, #:default => 4,
            services: Integer, #:default => 16,
            apps: Integer, #:default => 20
          },

          optional(:index) => Integer, # Component index (cc-0, cc-1, etc)
          optional(:name) => String, # Component name (api_z1, api_z2)
          optional(:local_route) => String, # If set, use this to determine the IP address that is returned in discovery messages

          :nginx => {
            use_nginx: bool,
            instance_socket: String,
          },

          :quota_definitions => Hash,
          :default_quota_definition => String,

          :security_group_definitions => [
            {
              'name' => String,
              'rules' => [
                {
                  'protocol' => String,
                  'destination' => String,
                  optional('ports') => String,
                  optional('type') => Integer,
                  optional('code') => Integer
                }
              ]
            }
          ],
          :default_staging_security_groups => [String],
          :default_running_security_groups => [String],

          :resource_pool => {
            optional(:maximum_size) => Integer,
            optional(:minimum_size) => Integer,
            :resource_directory_key => String,
            :fog_connection => Hash,
            optional(:fog_aws_storage_options) => Hash
          },

          :buildpacks => {
            :buildpack_directory_key => String,
            :fog_connection => Hash,
            optional(:fog_aws_storage_options) => Hash
          },

          :packages => {
            optional(:max_package_size) => Integer,
            optional(:max_valid_packages_stored) => Integer,
            :app_package_directory_key => String,
            :fog_connection => Hash,
            optional(:fog_aws_storage_options) => Hash
          },

          :droplets => {
            droplet_directory_key: String,
            optional(:max_staged_droplets_stored) => Integer,
            :fog_connection => Hash,
            optional(:fog_aws_storage_options) => Hash
          },

          :db_encryption_key => String,

          optional(:varz_port) => Integer,
          optional(:varz_user) => String,
          optional(:varz_password) => String,
          optional(:disable_custom_buildpacks) => bool,
          optional(:broker_client_timeout_seconds) => Integer,
          optional(:broker_client_default_async_poll_interval_seconds) => Integer,
          optional(:broker_client_max_async_poll_duration_minutes) => Integer,
          optional(:uaa_client_name) => String,
          optional(:uaa_client_secret) => String,
          optional(:uaa_client_scope) => String,

          optional(:cloud_controller_username_lookup_client_name) => String,
          optional(:cloud_controller_username_lookup_client_secret) => String,

          optional(:renderer) => {
            max_results_per_page: Integer,
            default_results_per_page: Integer,
            max_inline_relations_depth: Integer,
          },

          optional(:loggregator) => {
            optional(:router) => String,
            optional(:internal_url) => String,
          },

          doppler: {
            url: String
          },

          optional(:request_timeout_in_seconds) => Integer,
          optional(:skip_cert_verify) => bool,

          optional(:install_buildpacks) => [
            {
              'name' => String,
              optional('package') => String,
              optional('file') => String,
              optional('enabled') => bool,
              optional('locked') => bool,
              optional('position') => Integer,
            }
          ],

          optional(:app_bits_upload_grace_period_in_seconds) => Integer,
          optional(:default_locale) => String,
          optional(:allowed_cors_domains) => [String],

          optional(:users_can_select_backend) => bool,
          optional(:routing_api) => {
            url: String,
            routing_client_name: String,
            routing_client_secret: String,
          },

          optional(:route_services_enabled) => bool,
          optional(:volume_services_enabled) => bool,

          optional(:reserved_private_domains) => String,

          optional(:security_event_logging) => {
            enabled: bool
          },

          optional(:bits_service) => {
            enabled: bool,
            optional(:public_endpoint) => String,
            optional(:private_endpoint) => String
          },

          optional(:rate_limiter) => {
            enabled: bool,
            optional(:general_limit) => Integer,
            optional(:unauthenticated_limit) => Integer,
            optional(:reset_interval_in_minutes) => Integer,
          },
          :shared_isolation_segment_name => String,

          optional(:diego) => {
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
            optional(:temporary_oci_buildpack_mode) => enum('oci-phase-1'),
            tps_url: String,
            use_privileged_containers_for_running: bool,
            use_privileged_containers_for_staging: bool,
            optional(:insecure_docker_registry_list) => [String],
            optional(:docker_staging_stack) => String,
          },

          optional(:perform_blob_cleanup) => bool,

          optional(:allow_app_ssh_access) => bool,

          optional(:development_mode) => bool,

          optional(:external_host) => String,

          optional(:statsd_host) => String,
          optional(:statsd_port) => Integer,
          optional(:system_hostnames) => [String],
          optional(:default_app_ssh_access) => bool,

          optional(:diego_sync) => { frequency_in_seconds: Integer },
          optional(:expired_blob_cleanup) => { cutoff_age_in_days: Integer },
          optional(:expired_orphaned_blob_cleanup) => { cutoff_age_in_days: Integer },
          optional(:expired_resource_cleanup) => { cutoff_age_in_days: Integer },
          optional(:orphaned_blobs_cleanup) => { cutoff_age_in_days: Integer },
          optional(:pending_builds) => {
            expiration_in_seconds: Integer,
            frequency_in_seconds: Integer,
          },
          optional(:pending_droplets) => {
            expiration_in_seconds: Integer,
            frequency_in_seconds: Integer,
          },
          optional(:pollable_job_cleanup) => { cutoff_age_in_days: Integer },
          optional(:service_usage_events) => { cutoff_age_in_days: Integer },

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
        def configure_components(config)
          QuotaDefinition.configure(config)
        end
      end
    end
  end
end
