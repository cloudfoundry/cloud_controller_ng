require "vcap/config"
require "cloud_controller/account_capacity"
require "uri"

# Config template for cloud controller
class VCAP::CloudController::Config < VCAP::Config
  DEFAULT_CONFIG_PATH = File.expand_path("../../../../config/dev.yml", __FILE__)

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

      :system_domains => [ String ],

      # TODO: put back once json schema is sorted out
      # :allow_debug => BoolSchema,

      :uaa => {
        :url                => String,
        :resource_id        => String,
        :symmetric_secret   => String
      },

      :logging => {
        :level              => String,      # debug, info, etc.
        optional(:file)     => String,      # Log file to use
        optional(:syslog)   => String,      # Name to associate with syslog messages (should start with 'vcap.')
      },

      :nats_uri              => String,     # NATS uri of the form nats://<user>:<pass>@<host>:<port>
      :pid_filename          => String,     # Pid filename to use

      optional(:directories) => {
        optional(:tmpdir)    => String,
        optional(:droplets)  => String,
        optional(:staging_manifests) => String,
      },

      optional(:runtimes_file) => String,

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

      :cc_partition => String,

      # TODO: use new defaults to set these defaults
      optional(:default_account_capacity) => {
        :memory   => Fixnum,   #:default => 2048,
        :app_uris => Fixnum, #:default => 4,
        :services => Fixnum, #:default => 16,
        :apps     => Fixnum, #:default => 20
      },

      # TODO: use new defaults to set these defaults
      optional(:admin_account_capacity) => {
        :memory   => Fixnum,   #:default => 2048,
        :app_uris => Fixnum, #:default => 4,
        :services => Fixnum, #:default => 16,
        :apps     => Fixnum, #:default => 20
      },

      optional(:index)       => Integer,    # Component index (cc-0, cc-1, etc)
      optional(:local_route) => String,     # If set, use this to determine the IP address that is returned in discovery messages

      :nginx => {
        :use_nginx  => bool,
        :instance_socket => String,
      },

      :service_lifecycle => {
        :max_upload_size => Integer,
        :upload_token => String,
        :upload_timeout => Integer,
        :serialization_data_server => [URI.regexp(["http", "https"])],
      },

      :quota_definitions => Hash,
      :default_quota_definition => String,

      :resource_pool => {
        optional(:maximum_size) => Integer,
        optional(:minimum_size) => Integer,
        optional(:resource_directory_key) => String,
        :fog_connection => {
          :provider => String,
          optional(:aws_access_key_id) => String,
          optional(:aws_secret_access_key) => String,
          optional(:local_root) => String
        }
      },

      :packages => {
        optional(:max_droplet_size) => Integer,
        optional(:app_package_directory_key) => String,
        :fog_connection => {
          :provider => String,
          optional(:aws_access_key_id) => String,
          optional(:aws_secret_access_key) => String,
          optional(:local_root) => String
        }
      },

      :droplets => {
        optional(:max_droplet_size) => Integer,
        optional(:droplet_directory_key) => String,
        :fog_connection => {
          :provider => String,
          optional(:aws_access_key_id) => String,
          optional(:aws_secret_access_key) => String,
          optional(:local_root) => String
        }
      }
    }
  end

  def self.from_file(file_name)
    config = super(file_name)
    merge_defaults(config)
  end

  def self.merge_defaults(config)
    config[:directories] ||= {}
    config[:directories][:staging_manifests] ||=
      File.join(config_dir, "frameworks")
    config[:runtimes_file] ||= File.join(config_dir, "runtimes.yml")
    config
  end

  def self.configure(config)
    mbus = VCAP::CloudController::MessageBus.new(config)
    VCAP::CloudController::MessageBus.instance = mbus

    VCAP::CloudController::AccountCapacity.configure(config)
    VCAP::CloudController::ResourcePool.instance =
      VCAP::CloudController::ResourcePool.new(config)
    VCAP::CloudController::AppPackage.configure(config)
    VCAP::CloudController::AppStager.configure(config, mbus)
    VCAP::CloudController::LegacyStaging.configure(config)

    VCAP::CloudController::DeaPool.configure(config, mbus)
    VCAP::CloudController::DeaClient.configure(config, mbus)
    VCAP::CloudController::HealthManagerClient.configure(mbus)

    VCAP::CloudController::LegacyBulk.configure(config, mbus)
    VCAP::CloudController::Models::QuotaDefinition.configure(config)
  end

  def self.config_dir
    @config_dir ||= File.expand_path("../../../config", __FILE__)
  end
end
