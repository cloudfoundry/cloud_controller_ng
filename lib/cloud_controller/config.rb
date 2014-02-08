require "vcap/config"
require "cloud_controller/account_capacity"
require "uri"

# Config template for cloud controller
module VCAP::CloudController
  class Config < VCAP::Config
    define_schema do
      {
        :port => Integer,
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
        :default_app_memory => Fixnum,
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
        },

        optional(:stacks_file) => String,

        :db => {
          :database                   => String,     # db connection string for sequel
          optional(:log_level)        => String,     # debug, info, etc.
          optional(:max_connections)  => Integer,    # max connections in the connection pool
          optional(:pool_timeout)     => Integer     # timeout before raising an error when connection can't be established to the db
        },

        :bulk_api => {
          :auth_user  => String,
          :auth_password => String,
        },

        optional(:staging) => {
          optional(:max_staging_runtime) => Fixnum,
          optional(:minimum_staging_memory_mb) => Fixnum,
          optional(:auth) => {
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

        :resource_pool => {
          optional(:maximum_size) => Integer,
          optional(:minimum_size) => Integer,
          optional(:resource_directory_key) => String,
          :fog_connection => Hash
        },

        :packages => {
          optional(:max_droplet_size) => Integer,
          optional(:app_package_directory_key) => String,
          :fog_connection => Hash
        },

        :droplets => {
          optional(:max_droplet_size) => Integer,
          optional(:droplet_directory_key) => String,
          :fog_connection => Hash
        },

        :db_encryption_key => String,

        optional(:trial_db) => {
          :guid => String,
        },

        optional(:tasks_disabled) => bool,

        optional(:hm9000_noop) => bool,
        optional(:flapping_crash_count_threshold) => Integer,

        optional(:varz_port) => Integer,
        optional(:varz_user) => String,
        optional(:varz_password) => String,
        optional(:disable_custom_buildpacks) => bool,
        optional(:broker_client_timeout_seconds) => Integer,

        :renderer => {
          :max_results_per_page => Integer,
          :default_results_per_page => Integer,
        },
      }
    end

    class << self
      def from_file(file_name)
        config = super(file_name)
        merge_defaults(config)
      end

      attr_reader :config, :message_bus

      def configure_components(config)
        @config = config

        Encryptor.db_encryption_key = config[:db_encryption_key]
        AccountCapacity.configure(config)
        ResourcePool.instance = ResourcePool.new(config)

        QuotaDefinition.configure(config)
        Stack.configure(config[:stacks_file])
        ServicePlan.configure(config[:trial_db])
        App.configure(!config[:disable_custom_buildpacks])

        run_initializers(config)
      end

      def configure_components_depending_on_message_bus(message_bus)
        @message_bus = message_bus
        stager_pool = StagerPool.new(@config, message_bus)
        dea_pool = DeaPool.new(message_bus)

        AppObserver.configure(@config, message_bus, dea_pool, stager_pool)

        blobstore_url_generator = CloudController::DependencyLocator.instance.blobstore_url_generator
        DeaClient.configure(@config, message_bus, dea_pool, stager_pool, blobstore_url_generator)

        LegacyBulk.configure(@config, message_bus)
      end

      def config_dir
        @config_dir ||= File.expand_path("../../../config", __FILE__)
      end


      def run_initializers(config)
        return if @initialized

        Dir.glob(File.expand_path('../../../config/initializers/*.rb', __FILE__)).each do |file|
          require file
          method = File.basename(file).sub(".rb", "").gsub("-", "_")
          CCInitializers.send(method, config)
        end
        @initialized = true
      end

      private
      def merge_defaults(config)
        config[:stacks_file] ||= File.join(config_dir, "stacks.yml")
        config[:directories] ||= {}
        config[:maximum_app_disk_in_mb] ||= 2048
        config
      end
    end
  end
end
