require "vcap/config"
require "cloud_controller/account_capacity"
require "uri"
require "cloud_controller/diego/traditional/staging_completion_handler"
require "cloud_controller/diego/docker/staging_completion_handler"

# Config template for cloud controller
module VCAP::CloudController
  # rubocop:disable ClassLength
  class Config < VCAP::Config
    define_schema do
      {
        :external_port => Integer,
        # Public host is the address CC_ng exposed to others to connect,
        # it may be different from the local ip of CC_ng.
        # You can leave it nil unless you are running CC_ng inside Docker.
        optional(:public_host) => String,
        :external_protocol => String,
        :info => {
          :name            => String,
          :build           => String,
          :version         => Fixnum,
          :support_address => String,
          :description     => String,
        },

        :system_domain => String,
        :system_domain_organization => enum(String, NilClass),
        :app_domains => [ String ],
        :app_events => {
          :cutoff_age_in_days => Fixnum
        },
        :app_usage_events => {
          :cutoff_age_in_days => Fixnum
        },
        :audit_events => {
          :cutoff_age_in_days => Fixnum
        },
        :failed_jobs => {
          :cutoff_age_in_days => Fixnum
        },
        optional(:billing_event_writing_enabled) => bool,
        :default_app_memory => Fixnum,
        :default_app_disk_in_mb => Fixnum,
        optional(:maximum_app_disk_in_mb) => Fixnum,
        :maximum_health_check_timeout => Fixnum,

        optional(:allow_debug) => bool,

        optional(:login) => {
          :url      => String
        },

        :uaa => {
          :url                => String,
          :resource_id        => String,
          optional(:symmetric_secret)   => String
        },

        :logging => {
          :level              => String,      # debug, info, etc.
          optional(:file)     => String,      # Log file to use
          optional(:syslog)   => String,      # Name to associate with syslog messages (should start with 'vcap.')
        },

        :message_bus_servers   => [String],   # A list of NATS uris of the form nats://<user>:<pass>@<host>:<port>
        :pid_filename          => String,     # Pid filename to use

        optional(:directories) => {
          optional(:tmpdir)    => String,
          optional(:diagnostics) => String,
        },

        optional(:stacks_file) => String,
        optional(:newrelic_enabled) => bool,

        optional(:db) => {
          optional(:database)         => String,     # db connection string for sequel
          optional(:log_level)        => String,     # debug, info, etc.
          optional(:max_connections)  => Integer,    # max connections in the connection pool
          optional(:pool_timeout)     => Integer     # timeout before raising an error when connection can't be established to the db
        },

        :bulk_api => {
          :auth_user  => String,
          :auth_password => String,
        },

        :staging => {
          :timeout_in_seconds => Fixnum,
          optional(:minimum_staging_memory_mb) => Fixnum,
          optional(:minimum_staging_disk_mb) => Fixnum,
          :auth => {
            :user => String,
            :password => String,
          }
        },

        :cc_partition => String,

        optional(:default_account_capacity) => {
          :memory   => Fixnum,   #:default => 2048,
          :app_uris => Fixnum, #:default => 4,
          :services => Fixnum, #:default => 16,
          :apps     => Fixnum, #:default => 20
        },

        optional(:admin_account_capacity) => {
          :memory   => Fixnum,   #:default => 2048,
          :app_uris => Fixnum, #:default => 4,
          :services => Fixnum, #:default => 16,
          :apps     => Fixnum, #:default => 20
        },

        optional(:index)       => Integer,    # Component index (cc-0, cc-1, etc)
        optional(:name)        => String,     # Component name (api_z1, api_z2)
        optional(:local_route) => String,     # If set, use this to determine the IP address that is returned in discovery messages

        :nginx => {
          :use_nginx  => bool,
          :instance_socket => String,
        },

        :quota_definitions => Hash,
        :default_quota_definition => String,

        :security_group_definitions => [
          {
            "name" => String,
            "rules" => [
              {
                "protocol" => String,
                "destination" => String,
                optional("ports") => String,
                optional("type") => Integer,
                optional("code") => Integer
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
          :fog_connection => Hash
        },

        :packages => {
          optional(:max_package_size) => Integer,
          :app_package_directory_key => String,
          :fog_connection => Hash
        },

        :droplets => {
          :droplet_directory_key => String,
          :fog_connection => Hash
        },

        :db_encryption_key => String,

        optional(:flapping_crash_count_threshold) => Integer,

        optional(:varz_port) => Integer,
        optional(:varz_user) => String,
        optional(:varz_password) => String,
        optional(:disable_custom_buildpacks) => bool,
        optional(:broker_client_timeout_seconds) => Integer,
        optional(:uaa_client_name) => String,
        optional(:uaa_client_secret) => String,
        optional(:uaa_client_scope) => String,

        :renderer => {
          :max_results_per_page => Integer,
          :default_results_per_page => Integer,
        },

        optional(:loggregator) => {
          optional(:router) => String,
          optional(:shared_secret) => String,
        },

        optional(:request_timeout_in_seconds) => Integer,
        optional(:skip_cert_verify) => bool,

        optional(:install_buildpacks) => [
          {
            "name" => String,
            optional("package") => String,
            optional("file") => String,
            optional("enabled") => bool,
            optional("locked") => bool,
            optional("position") => Integer,
          }
        ],

        optional(:app_bits_upload_grace_period_in_seconds) => Integer,

        optional(:default_locale) => String,
        optional(:allowed_cors_domains) => [ String ],

        optional(:diego) => {
          optional(:staging) => enum(
            "disabled",
            "optional",
            "required",
          ),
          optional(:running) => enum(
            "disabled",
            "optional",
            "required",
          )
        },

        optional(:dea_advertisement_timeout_in_seconds) => Integer,
      }
    end

    class << self
      def from_file(file_name)
        config = super(file_name)
        merge_defaults(config).tap do |c|
          validate!(c)
        end
      end

      attr_reader :config, :message_bus

      def configure_components(config)
        @config = config

        Encryptor.db_encryption_key = config[:db_encryption_key]
        AccountCapacity.configure(config)
        ResourcePool.instance = ResourcePool.new(config)

        QuotaDefinition.configure(config)
        Stack.configure(config[:stacks_file])

        run_initializers(config)
      end

      def configure_components_depending_on_message_bus(message_bus)
        @message_bus = message_bus
        dependency_locator = CloudController::DependencyLocator.instance
        dependency_locator.config = @config
        hm_client = Dea::HM9000::Client.new(@message_bus, @config)
        dependency_locator.register(:health_manager_client, hm_client)
        diego_client = Diego::Client.new(Diego::ServiceRegistry.new(message_bus))
        dependency_locator.register(:diego_client, diego_client)
        dependency_locator.register(:upload_handler, UploadHandler.new(config))
        dependency_locator.register(:app_event_repository, Repositories::Runtime::AppEventRepository.new)
        dependency_locator.register(:instances_reporter, CompositeInstancesReporter.new(diego_client, hm_client))

        blobstore_url_generator = dependency_locator.blobstore_url_generator
        stager_pool = Dea::StagerPool.new(@config, message_bus, blobstore_url_generator)
        dea_pool = Dea::Pool.new(@config, message_bus)
        backends = Backends.new(@config, message_bus, dea_pool, stager_pool)
        dependency_locator.register(:backends, backends)

        diego_client.connect!

        Dea::Client.configure(@config, message_bus, dea_pool, stager_pool, blobstore_url_generator)

        Diego::Traditional::StagingCompletionHandler.new(message_bus, backends).subscribe!
        Diego::Docker::StagingCompletionHandler.new(message_bus, backends).subscribe!

        AppObserver.configure(backends)

        LegacyBulk.configure(@config, message_bus)

        BulkApi.configure(@config)
      end

      def config_dir
        @config_dir ||= File.expand_path("../../../config", __FILE__)
      end

      def run_initializers(config)
        return if @initialized
        run_initializers_in_directory(config, '../../../config/initializers/*.rb')
        if config[:newrelic_enabled]
          require "newrelic_rpm"
          run_initializers_in_directory(config, '../../../config/newrelic/initializers/*.rb')
        end
        @initialized = true
      end

      def run_initializers_in_directory(config, path)
        Dir.glob(File.expand_path(path, __FILE__)).each do |file|
          require file
          method = File.basename(file).sub(".rb", "").gsub("-", "_")
          CCInitializers.send(method, config)
        end
      end

      def merge_defaults(config)
        config[:stacks_file] ||= File.join(config_dir, "stacks.yml")
        config[:maximum_app_disk_in_mb] ||= 2048
        config[:request_timeout_in_seconds] ||= 300
        config[:directories] ||= {}
        config[:billing_event_writing_enabled] = true if config[:billing_event_writing_enabled].nil?
        config[:skip_cert_verify] = false if config[:skip_cert_verify].nil?
        config[:app_bits_upload_grace_period_in_seconds] ||= 0
        config[:db] ||= {}
        config[:db][:database] ||= ENV["DB_CONNECTION_STRING"]
        config[:default_locale] ||= "en_US"
        config[:allowed_cors_domains] ||= []
        config[:diego] ||= {}
        config[:diego][:staging] ||= "disabled"
        config[:diego][:running] ||= "disabled"
        config[:diego_docker] ||= false
        config[:dea_advertisement_timeout_in_seconds] ||= 10
        sanitize(config)
      end

      def validate!(config)
        if (config[:diego][:staging] == 'disabled' && config[:diego][:running] != 'disabled') ||
          (config[:diego][:staging] == 'optional' && config[:diego][:running] == 'required') ||
          (config[:diego][:running] == 'disabled' && config[:diego_docker])

          raise "Invalid diego configuration"
        end
      end

      private

      def sanitize(config)
        sanitize_grace_period(config)
        sanitize_staging_auth(config)
        config
      end

      def sanitize_grace_period(config)
        grace_period = config[:app_bits_upload_grace_period_in_seconds]
        config[:app_bits_upload_grace_period_in_seconds] = 0 if grace_period < 0
      end

      def sanitize_staging_auth(config)
        auth = config[:staging][:auth]
        auth[:user] = escape_userinfo(auth[:user]) unless valid_in_userinfo?(auth[:user])
        auth[:password] = escape_userinfo(auth[:password]) unless valid_in_userinfo?(auth[:password])
      end

      def escape_userinfo(value)
        URI::escape(value, "%#{URI::REGEXP::PATTERN::RESERVED}")
      end

      def valid_in_userinfo?(value)
        URI::REGEXP::PATTERN::USERINFO.match(value)
      end
    end
  end
end
