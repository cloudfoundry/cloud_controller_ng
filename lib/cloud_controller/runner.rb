require 'steno'
require 'optparse'
require 'i18n'
require 'i18n/backend/fallbacks'
require 'vcap/uaa_token_decoder'
require 'vcap/uaa_verification_keys'
require 'cf_message_bus/message_bus'
require 'loggregator_emitter'
require 'loggregator'
require 'cloud_controller/dea/sub_system'
require 'cloud_controller/rack_app_builder'
require 'cloud_controller/metrics/periodic_updater'
require 'cloud_controller/metrics/request_metrics'

require_relative 'message_bus_configurer'

module VCAP::CloudController
  class Runner
    attr_reader :config_file, :insert_seed_data

    def initialize(argv)
      @argv = argv

      # default to production. this may be overridden during opts parsing
      ENV['NEW_RELIC_ENV'] ||= 'production'

      @config_file = File.expand_path('../../../config/cloud_controller.yml', __FILE__)
      parse_options!
      parse_config

      setup_i18n

      @log_counter = Steno::Sink::Counter.new
    end

    def setup_i18n
      CloudController::Errors::ApiError.setup_i18n(Dir[File.expand_path('../../../vendor/errors/i18n/*.yml', __FILE__)], @config[:default_locale])
    end

    def logger
      setup_logging
      @logger ||= Steno.logger('cc.runner')
    end

    def options_parser
      @parser ||= OptionParser.new do |opts|
        opts.on('-c', '--config [ARG]', 'Configuration File') do |opt|
          @config_file = opt
        end
      end
    end

    def deprecation_warning(message)
      puts message
    end

    def parse_options!
      options_parser.parse! @argv
    rescue
      puts options_parser
      exit 1
    end

    def parse_config
      @config = Config.from_file(@config_file)
    rescue Membrane::SchemaValidationError => ve
      puts "ERROR: There was a problem validating the supplied config: #{ve}"
      exit 1
    rescue => e
      puts "ERROR: Failed loading config from file '#{@config_file}': #{e}"
      exit 1
    end

    def run!
      create_pidfile

      EM.run do
        begin
          message_bus = MessageBus::Configurer.new(servers: @config[:message_bus_servers], logger: logger).go

          start_cloud_controller(message_bus)

          Dea::SubSystem.setup!(message_bus)

          VCAP::Component.varz.threadsafe! # initialize varz

          request_metrics = VCAP::CloudController::Metrics::RequestMetrics.new(statsd_client)
          gather_periodic_metrics(message_bus)

          builder = RackAppBuilder.new
          app     = builder.build(@config, request_metrics)

          start_thin_server(app)
        rescue => e
          logger.error "Encountered error: #{e}\n#{e.backtrace.join("\n")}"
          raise e
        end
      end
    end

    def gather_periodic_metrics(message_bus)
      logger.info('setting up metrics')

      logger.info('registering with collector')
      register_with_collector(message_bus)

      logger.info('starting periodic metrics updater')
      periodic_updater.setup_updates
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

    def stop!
      stop_thin_server
      logger.info('Stopping EventMachine')
      EM.stop
    end

    private

    def start_cloud_controller(message_bus)
      setup_logging
      setup_db
      Config.configure_components(@config)
      setup_loggregator_emitter

      @config[:external_host] = VCAP.local_ip(@config[:local_route])
      Config.configure_components_depending_on_message_bus(message_bus)
    end

    def create_pidfile
      pid_file = VCAP::PidFile.new(@config[:pid_filename])
      pid_file.unlink_at_exit
    rescue
      puts "ERROR: Can't create pid file #{@config[:pid_filename]}"
      exit 1
    end

    def setup_logging
      return if @setup_logging
      @setup_logging = true

      StenoConfigurer.new(@config[:logging]).configure do |steno_config_hash|
        steno_config_hash[:sinks] << @log_counter
      end
    end

    def setup_db
      logger.info "db config #{@config[:db]}"
      db_logger = Steno.logger('cc.db')
      DB.load_models(@config[:db], db_logger)
    end

    def setup_loggregator_emitter
      if @config[:loggregator] && @config[:loggregator][:router]
        Loggregator.emitter = LoggregatorEmitter::Emitter.new(@config[:loggregator][:router], 'cloud_controller', 'API', @config[:index])
        Loggregator.logger = logger
      end
    end

    def start_thin_server(app)
      @thin_server = if @config[:nginx][:use_nginx]
                       Thin::Server.new(@config[:nginx][:instance_socket], signals: false)
                     else
                       Thin::Server.new(@config[:external_host], @config[:external_port], signals: false)
                     end

      @thin_server.app = app
      trap_signals

      # The routers proxying to us handle killing inactive connections.
      # Set an upper limit just to be safe.
      @thin_server.timeout = @config[:request_timeout_in_seconds]
      @thin_server.threaded = true
      @thin_server.start!
    end

    def stop_thin_server
      logger.info('Stopping Thin Server.')
      @thin_server.stop if @thin_server
    end

    def register_with_collector(message_bus)
      VCAP::Component.register(
        type: 'CloudController',
        host: @config[:external_host],
        port: @config[:varz_port],
        user: @config[:varz_user],
        password: @config[:varz_password],
        index: @config[:index],
        nats: message_bus,
        logger: logger,
        log_counter: @log_counter
      )
    end

    def periodic_updater
      @periodic_updater ||= VCAP::CloudController::Metrics::PeriodicUpdater.new(
        ::VCAP::Component.varz.synchronize { ::VCAP::Component.varz[:start] }, # this can become Time.now.utc after we remove varz
        @log_counter,
        [
          VCAP::CloudController::Metrics::VarzUpdater.new,
          VCAP::CloudController::Metrics::StatsdUpdater.new(statsd_client)
        ])
    end

    def statsd_client
      return @statsd_client if @statsd_client

      logger.info("configuring statsd server at #{@config[:statsd_host]}:#{@config[:statsd_port]}")
      Statsd.logger = Steno.logger('statsd.client')
      @statsd_client = Statsd.new(@config[:statsd_host], @config[:statsd_port].to_i)
    end

    def collect_diagnostics
      @diagnostics_dir ||= @config[:directories][:diagnostics]
      @diagnostics_dir ||= Dir.mktmpdir
      file = VCAP::CloudController::Diagnostics.new.collect(@diagnostics_dir, periodic_updater)
      logger.warn("Diagnostics written to #{file}")
    rescue => e
      logger.warn("Failed to capture diagnostics: #{e}")
    end
  end
end
