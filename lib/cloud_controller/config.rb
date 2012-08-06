require "vcap/config"

# Config template for cloud controller
class VCAP::CloudController::Config < VCAP::Config
  DEFAULT_CONFIG_PATH = File.expand_path("../../../../config/dev.yml", __FILE__)

  define_schema do
    {
      :info => {
        :name            => String,
        :build           => String,
        :version         => Fixnum,
        :support_address => String,
        :description     => String,
      },

      # TODO: put back once json schema is sorted out
      # :allow_debug => BoolSchema,

      :uaa => {
        :url                => String,
        :resource_id        => String,
        :symmetric_secret   => String
      },

      :quota_manager => {
        :base_url                   => String,
        :auth_token                 => String,
        optional(:http_timeout_sec) => Integer
      },

      :logging => {
        :level              => String,      # debug, info, etc.
        optional(:file)     => String,      # Log file to use
        optional(:syslog)   => String,      # Name to associate with syslog messages (should start with 'vcap.')
      },

      :nats_uri              => String,     # NATS uri of the form nats://<user>:<pass>@<host>:<port>
      :pid_filename          => String,     # Pid filename to use
      optional(:dirs) => {
        optional(:tmp)       => String,     # Default is /tmp
      },

      :db => {
        :database                   => String,     # db connection string for sequel
        optional(:log_level)        => String,     # debug, info, etc.
        optional(:max_connections)  => Integer,    # max connections in the connection pool
        optional(:pool_timeout)     => Integer     # timeout before raising an error when connection can't be established to the db
      },

      :legacy_framework_manifest => Hash,

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
    }
  end

  def self.configure(config)
    # TODO: this introduces 2 config styles.  CC takes config
    # via per instance constructor.  Remove that in favor of this
    # method as there will be more along these lines.
    VCAP::CloudController::MessageBus.configure(config)
    VCAP::CloudController::RestController::QuotaManager.configure(config)
    VCAP::CloudController::Models::AccountCapacity.configure(config)
    VCAP::CloudController::ResourcePool.configure(config)
    VCAP::CloudController::FilesystemPool.configure(config)
    VCAP::CloudController::AppPackage.configure(config)
    VCAP::CloudController::LegacyStaging.configure(config)
  end
end
