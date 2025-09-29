require 'puma'
require 'puma/configuration'
require 'puma/events'
require 'cloud_controller/logs/steno_io'

module VCAP::CloudController
  class PumaRunner
    def initialize(config, app, logger, periodic_updater, request_logs)
      @logger = logger

      ENV['WEB_CONCURRENCY'] = 'auto' if config.get(:puma, :automatic_worker_count)
      puma_config = Puma::Configuration.new do |conf|
        if config.get(:nginx, :use_nginx)
          if config.get(:nginx, :instance_socket).nil? || config.get(:nginx, :instance_socket).empty?
            conf.bind 'tcp://0.0.0.0:3000'
          else
            conf.bind "unix://#{config.get(:nginx, :instance_socket)}"
          end
        else
          conf.bind "tcp://0.0.0.0:#{config.get(:external_port)}"
        end

        conf.workers(config.get(:puma, :workers) || 1) unless config.get(:puma, :automatic_worker_count)
        num_threads = config.get(:puma, :max_threads) || 1
        conf.threads(num_threads, num_threads)

        # In theory there shouldn't be any open connections when shutting down Puma as they have either been gracefully
        # drained or forcefully terminated (after cc.nginx_drain_timeout) by Nginx. Puma has some built-in (i.e. not
        # changeable) timeouts as well as some configurable timeouts.

        # Reduce the worker shutdown timeout to 15 seconds (default is 30).
        conf.worker_shutdown_timeout(15)
        # Reduce the thread shutdown timeout to 10 seconds (4 [force_shutdown_after] + 5 [SHUTDOWN_GRACE_TIME] + 1)
        conf.force_shutdown_after(4)

        # replace PidFormatter as we already have the pid in the Steno log record
        formatter = Puma::LogWriter::DefaultFormatter.new
        conf.log_formatter { |str| formatter.call(str) }

        conf.app app
        conf.before_fork do
          Sequel::Model.db.disconnect
        end
        conf.before_worker_boot do
          ENV['PROCESS_TYPE'] = 'puma_worker'
          prometheus_updater.update_gauge_metric(:cc_db_connection_pool_timeouts_total, 0, labels: { process_type: 'puma_worker' })
        end
        conf.before_worker_shutdown do
          request_logs.log_incomplete_requests if request_logs
        end
      end

      log_writer = Puma::LogWriter.new(StenoIO.new(logger, :info), StenoIO.new(logger, :error))

      events = Puma::Events.new
      events.after_booted do
        prometheus_updater.update_gauge_metric(:cc_db_connection_pool_timeouts_total, 0, labels: { process_type: 'main' })
        Thread.new do
          EM.run { periodic_updater.setup_updates }
        end
      end
      events.after_stopped do
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

    private

    def prometheus_updater
      CloudController::DependencyLocator.instance.prometheus_updater
    end
  end
end
