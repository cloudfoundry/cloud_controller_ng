require 'vcap/config'
require 'cloud_controller/account_capacity'
require 'uri'
require 'cloud_controller/backends/stagers'
require 'cloud_controller/backends/runners'
require 'cloud_controller/index_stopper'
require 'cloud_controller/backends/instances_reporters'
require 'repositories/service_event_repository'

module VCAP::CloudController
  class Config < VCAP::Config
    class InvalidConfigPath < StandardError
    end

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

    class << self
      def load_from_file(file_name)
        config = merge_defaults(from_file(file_name))
        @instance = new(config)
      end

      def config
        @instance
      end

      private :from_file

      private

      def merge_defaults(config)
        config[:stacks_file] ||= File.join(config_dir, 'stacks.yml')
        config[:maximum_app_disk_in_mb] ||= 2048
        config[:request_timeout_in_seconds] ||= 900
        config[:directories] ||= {}
        config[:skip_cert_verify] = false if config[:skip_cert_verify].nil?
        config[:app_bits_upload_grace_period_in_seconds] ||= 0
        config[:db] ||= {}
        config[:db][:database] ||= ENV['DB_CONNECTION_STRING']
        config[:default_locale] ||= 'en_US'
        config[:allowed_cors_domains] ||= []
        config[:staging][:minimum_staging_memory_mb] ||= 1024
        config[:staging][:minimum_staging_disk_mb] ||= 4096
        config[:staging][:minimum_staging_file_descriptor_limit] ||= 16384
        config[:broker_client_timeout_seconds] ||= 60
        config[:broker_client_default_async_poll_interval_seconds] ||= 60
        config[:packages][:max_valid_packages_stored] ||= 5
        config[:droplets][:max_staged_droplets_stored] ||= 5
        config[:bits_service] ||= { enabled: false }
        config[:rate_limiter] ||= { enabled: false }
        config[:rate_limiter][:general_limit] ||= 2000
        config[:rate_limiter][:reset_interval_in_minutes] ||= 60

        unless config.key?(:users_can_select_backend)
          config[:users_can_select_backend] = true
        end

        sanitize(config)
      end

      def config_dir
        @config_dir ||= File.expand_path('../../config', __dir__)
      end

      def sanitize(config)
        sanitize_grace_period(config)
        sanitize_staging_auth(config)
        sanitize_diego_properties(config)

        config
      end

      def sanitize_diego_properties(config)
        pid_limit = HashUtils.dig(config, :diego, :pid_limit)
        if pid_limit
          config[:diego][:pid_limit] = 0 if pid_limit < 0
        end
      end

      def sanitize_grace_period(config)
        grace_period = config[:app_bits_upload_grace_period_in_seconds]
        config[:app_bits_upload_grace_period_in_seconds] = 0 if grace_period < 0
      end

      def sanitize_staging_auth(config)
        auth = config[:staging][:auth]
        auth[:user] = escape_userinfo(auth[:user]) unless valid_in_userinfo?(auth[:user])
        auth[:password] = escape_password(auth[:password]) unless valid_in_userinfo?(auth[:password])
      end

      def escape_password(value)
        escape_userinfo(value).gsub(/\"/, '%22')
      end

      def escape_userinfo(value)
        URI.escape(value, "%#{URI::REGEXP::PATTERN::RESERVED}")
      end

      def valid_in_userinfo?(value)
        URI::REGEXP::PATTERN::USERINFO.match(value)
      end
    end

    attr_reader :config_hash

    def initialize(config_hash)
      @config_hash = config_hash
    end

    def configure_components
      Encryptor.db_encryption_key = get(:db_encryption_key)
      ResourcePool.instance = ResourcePool.new(self)

      QuotaDefinition.configure(self)
      Stack.configure(get(:stacks_file))

      PrivateDomain.configure(get(:reserved_private_domains))

      dependency_locator = CloudController::DependencyLocator.instance
      dependency_locator.config = self

      run_initializers

      AppObserver.configure(dependency_locator.stagers, dependency_locator.runners)
      InternalApi.configure(self)
    end

    def get(*keys)
      some_schema = self.class.schema
      invalid_config_path!(keys) unless valid_config_path?(keys, some_schema)

      HashUtils.dig(config_hash, *keys)
    end

    def set(key, value)
      config_hash[key] = value
    end

    def valid_config_path?(keys, some_schema)
      keys.each do |key|
        if some_schema.is_a?(Membrane::Schemas::Record) && some_schema.schemas.keys.include?(key)
          some_schema = some_schema.schemas[key]
        else
          invalid_config_path!(keys)
        end
      end
    end

    private

    def invalid_config_path!(keys)
      raise InvalidConfigPath.new(%("#{keys.join('.')}" is not a valid config key))
    end

    def run_initializers
      return if @initialized
      run_initializers_in_directory('../../../config/initializers/*.rb')
      if @config_hash[:newrelic_enabled]
        require 'newrelic_rpm'

        # We need to explicitly initialize NewRelic before running our initializers
        # When Rails is present, NewRelic adds itself to the Rails initializers instead
        # of initializing immediately.

        opts = if (Rails.env.test? || Rails.env.development?) && !ENV['NRCONFIG']
                 { env: ENV['NEW_RELIC_ENV'] || 'production', monitor_mode: false }
               else
                 { env: ENV['NEW_RELIC_ENV'] || 'production' }
               end

        NewRelic::Agent.manual_start(opts)
        run_initializers_in_directory('../../../config/newrelic/initializers/*.rb')
      end
      @initialized = true
    end

    def run_initializers_in_directory(path)
      Dir.glob(File.expand_path(path, __FILE__)).each do |file|
        require file
        method = File.basename(file).sub('.rb', '').tr('-', '_')
        CCInitializers.send(method, @config_hash)
      end
    end
  end
end
