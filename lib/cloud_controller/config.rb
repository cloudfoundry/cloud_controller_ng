require "vcap/config"
require "vcap/json_schema"

# Config template for cloud controller
class VCAP::CloudController::Config < VCAP::Config
  DEFAULT_CONFIG_PATH = File.expand_path("../../../../config/dev.yml", __FILE__)

  define_schema do
    {
      :uaa => {
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

      optional(:index)       => Integer,    # Component index (cc-0, cc-1, etc)
      optional(:local_route) => String,     # If set, use this to determine the IP address that is returned in discovery messages
    }
  end

  def self.configure(config)
    # TODO: this introduces 2 config styles.  CC takes config
    # via per instance constructor.  Remove that in favor of this
    # method as there will be more along these lines.
    VCAP::CloudController::RestController::QuotaManager.configure(config)
  end
end
