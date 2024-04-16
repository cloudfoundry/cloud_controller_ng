require 'puma'
require 'puma/configuration'
require 'puma/events'
require 'cloud_controller/logs/steno_io'

module VCAP::CloudController
  class PumaRunner
    def initialize(config, app, logger, periodic_updater, request_logs)
      @logger = logger

      puma_config = Puma::Configuration.new do |conf|
        if config.get(:nginx, :use_nginx)
          conf.bind "unix://#{config.get(:nginx, :instance_socket)}"
        else
          conf.bind "tcp://0.0.0.0:#{config.get(:external_port)}"
        end

        conf.workers(config.get(:puma, :workers) || 1)
        conf.threads(0, config.get(:puma, :max_threads) || 1)

        # In theory there shouldn't be any open connections when shutting down Puma as they have either been gracefully
        # drained or forcefully terminated (after cc.nginx_drain_timeout) by Nginx. Puma has some built-in (i.e. not
        # changeable) timeouts as well as some configurable timeouts.

        # Reduce the worker shutdown timeout to 15 seconds (default is 30).
        conf.worker_shutdown_timeout(15)
        # Reduce the thread shutdown timeout to 10 seconds (4 [force_shutdown_after] + 5 [SHUTDOWN_GRACE_TIME] + 1)
        conf.force_shutdown_after(4)

        conf.app app
        conf.before_fork do
          Sequel::Model.db.disconnect
        end
        conf.on_worker_shutdown do
          request_logs.log_incomplete_requests if request_logs
        end
      end

      log_writer = Puma::LogWriter.new(StenoIO.new(logger, :info), StenoIO.new(logger, :error))

      # replace PidFormatter as we already have the pid in the Steno log record
      puma_config.options[:log_formatter] = Puma::LogWriter::DefaultFormatter.new

      events = Puma::Events.new
      events.on_booted do
        Thread.new do
          EM.run { periodic_updater.setup_updates }
        end
      end
      events.on_stopped do
        EM.stop
      end

      @puma_launcher = Puma::Launcher.new(puma_config, log_writer:, events:)
    end

    def start!
      @puma_launcher.run
    rescue StandardError => e
      @logger.error "Encountered error: #{e}\n#{e.backtrace&.join("\n")}"
      raise e
    end
  end
end
