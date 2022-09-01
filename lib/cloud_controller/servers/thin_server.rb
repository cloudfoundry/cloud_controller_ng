module VCAP::CloudController
  class ThinServer
    attr_reader :logger

    def initialize(config, app, logger)
      @logger = logger
      @config = config
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
    end

    def start!
      logger.info("Starting thin server with #{EventMachine.threadpool_size} threads")
      @thin_server.start!
    end

    def stop!
      logger.info('Stopping Thin Server.')
      @thin_server.stop if @thin_server
      @request_logs.log_incomplete_requests if @request_logs
    end
  end
end
