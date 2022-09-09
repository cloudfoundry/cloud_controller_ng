module VCAP::CloudController
  class ThinRunner
    attr_reader :logger

    def initialize(config, app, logger, periodic_updater)
      @config = config
      @logger = logger
      @thin_server = if @config.get(:nginx, :use_nginx)
                       Thin::Server.new(@config.get(:nginx, :instance_socket), signals: false)
                     else
                       Thin::Server.new(@config.get(:external_host), @config.get(:external_port), signals: false)
                     end

      @thin_server.app = app

      # The routers proxying to us handle killing inactive connections.
      # Set an upper limit just to be safe.
      @thin_server.timeout = @config.get(:request_timeout_in_seconds)
      @thin_server.threaded = true
      @thin_server.threadpool_size = @config.get(:threadpool_size)
      @periodic_updater = periodic_updater
      @request_logs = VCAP::CloudController::Logs::RequestLogs.new(Steno.logger('cc.api'))
    end

    def start!
      EM.run do
        logger.info('starting periodic metrics updater')
        @periodic_updater.setup_updates
        trap_signals
        logger.info("Starting thin server with #{EventMachine.threadpool_size} threads")
        @thin_server.start!
      rescue => e
        logger.error "Encountered error: #{e}\n#{e.backtrace.join("\n")}"
        raise e
      end
    end

    def stop!
      logger.info('Stopping Thin Server.')
      @thin_server.stop if @thin_server
      logger.info('Stopping EventMachine')
      EM.stop
      @request_logs.log_incomplete_requests if @request_logs
    end

    def trap_signals
      %w(TERM INT QUIT).each do |signal|
        trap(signal) do
          EM.add_timer(0) do
            logger.warn("Caught signal #{signal}")
            stop!
          end
        end
      end

      trap('USR1') do
        EM.add_timer(0) do
          logger.warn('Collecting diagnostics')
          collect_diagnostics
        end
      end
    end

    def collect_diagnostics
      @diagnostics_dir ||= @config.get(:directories, :diagnostics)

      file = VCAP::CloudController::Diagnostics.new.collect(@diagnostics_dir)
      logger.warn("Diagnostics written to #{file}")
    rescue => e
      logger.warn("Failed to capture diagnostics: #{e}")
    end
  end
end
