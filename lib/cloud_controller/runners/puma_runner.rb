require 'puma'
require 'puma/configuration'
require 'puma/events'

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
        conf.threads(0, config.get(:puma, :max_threads)) if config.get(:puma, :max_threads)
        conf.workers config.get(:puma, :workers) if config.get(:puma, :workers)
        conf.app app
        conf.before_fork do
          Sequel::Model.db.disconnect
        end
        conf.on_worker_shutdown do
          request_logs.log_incomplete_requests if request_logs
        end
      end
      log_writer = Puma::LogWriter.stdio
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
      @logger.error "Encountered error: #{e}\n#{e.backtrace.join("\n")}"
      raise e
    end
  end
end
