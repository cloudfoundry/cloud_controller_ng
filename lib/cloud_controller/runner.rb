# Copyright (c) 2009-2012 VMware, Inc.

require "steno"
require "optparse"
require "vcap/uaa_util"
require "cf_message_bus/message_bus"
require "cf/registrar"
require "loggregator_emitter"
require "loggregator_messages"
require "loggregator"

require_relative "seeds"
require_relative "message_bus_configurer"

module VCAP::CloudController
  class Runner
    def initialize(argv)
      @argv = argv

      # default to production. this may be overriden during opts parsing
      ENV["RACK_ENV"] = "production"
      @config_file = File.expand_path("../../../config/cloud_controller.yml", __FILE__)
      parse_options!
      parse_config

      @log_counter = Steno::Sink::Counter.new
    end

    def logger
      @logger ||= Steno.logger("cc.runner")
    end

    def options_parser
      @parser ||= OptionParser.new do |opts|
        opts.on("-c", "--config [ARG]", "Configuration File") do |opt|
          @config_file = opt
        end

        opts.on("-m", "--run-migrations", "Run migrations") do
          @insert_seed_data = true
        end

        opts.on("-d", "--development-mode", "Run in development mode") do
          # this must happen before requring any modules that use sinatra,
          # otherwise it will not setup the environment correctly
          @development = true
          ENV["RACK_ENV"] = "development"
        end
      end
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

    def create_pidfile
      pid_file = VCAP::PidFile.new(@config[:pid_filename])
      pid_file.unlink_at_exit
    rescue
      puts "ERROR: Can't create pid file #{@config[:pid_filename]}"
      exit 1
    end

    def setup_logging
      steno_config = Steno::Config.to_config_hash(@config[:logging])
      steno_config[:context] = Steno::Context::ThreadLocal.new
      steno_config[:sinks] << @log_counter
      Steno.init(Steno::Config.new(steno_config))
    end

    def setup_db
      logger.info "db config #{@config[:db]}"
      db_logger = Steno.logger("cc.db")
      DB.connect(db_logger, @config[:db])
      DB.load_models
    end

    def setup_loggregator_emitter
      if @config[:loggregator] && @config[:loggregator][:router]
        Loggregator.emitter = LoggregatorEmitter::Emitter.new(@config[:loggregator][:router], LogMessage::SourceType::CLOUD_CONTROLLER, @config[:index])
      end
    end

    def development?
      @development ||= false
    end

    def run!
      EM.run do
        config = @config.dup
        message_bus = MessageBusConfigurer::Configurer.new(:uri => config[:message_bus_uri], :logger => logger).go
        start_cloud_controller(message_bus)
        Seeds.write_seed_data(config) if @insert_seed_data
        app = create_app(config, message_bus)
        start_thin_server(app, config)
        registrar.register_with_router
      end
    end

    def trap_signals
      %w(TERM INT QUIT).each do |signal|
        trap(signal) do
          logger.warn("Caught signal #{signal}")
          stop!
        end
      end
    end

    def stop!
      logger.info("Unregistering routes.")

      registrar.shutdown do
        stop_thin_server
        EM.stop
      end
    end

    def merge_vcap_config
      services = JSON.parse(ENV["VCAP_SERVICES"])
      pg_key = services.keys.select { |svc| svc =~ /postgres/i }.first
      c = services[pg_key].first["credentials"]
      @config[:db][:database] = "postgres://#{c["user"]}:#{c["password"]}@#{c["hostname"]}:#{c["port"]}/#{c["name"]}"
      @config[:port] = ENV["VCAP_APP_PORT"].to_i
    end

    private

    def start_cloud_controller(message_bus)
      create_pidfile

      setup_logging
      setup_db
      setup_loggregator_emitter

      @config[:bind_address] = VCAP.local_ip(@config[:local_route])

      Config.configure(@config)
      Config.configure_message_bus(message_bus)
    end

    def create_app(config, message_bus)
      token_decoder = VCAP::UaaTokenDecoder.new(config[:uaa])

      register_component(message_bus)

      Rack::Builder.new do
        use Rack::CommonLogger

        DeaClient.run
        AppObserver.run

        LegacyBulk.register_subscription

        VCAP::CloudController.health_manager_respondent = \
          HealthManagerRespondent.new(
            DeaClient,
            message_bus)
        VCAP::CloudController.health_manager_respondent.handle_requests

        VCAP::CloudController.dea_respondent = DeaRespondent.new(message_bus)

        VCAP::CloudController.dea_respondent.start

        map "/" do
          run Controller.new(config, token_decoder)
        end
      end
    end

    def start_thin_server(app, config)
      if @config[:nginx][:use_nginx]
        @thin_server = Thin::Server.new(
            config[:nginx][:instance_socket],
            :signals => false
        )
      else
        @thin_server = Thin::Server.new(@config[:bind_address], @config[:port])
      end

      @thin_server.app = app
      trap_signals

      # The routers proxying to us handle killing inactive connections.
      # Set an upper limit just to be safe.
      @thin_server.timeout = 15 * 60 # 15 min
      @thin_server.threaded = true
      @thin_server.start!
    end

    def stop_thin_server
      @thin_server.stop if @thin_server
    end

    def registrar
      @registrar ||= Cf::Registrar.new(
          :mbus => @config[:message_bus_uri],
          :host => @config[:bind_address],
          :port => @config[:port],
          :uri => @config[:external_domain],
          :tags => {:component => "CloudController"},
          :index => @config[:index]
      )
    end

    def register_component(message_bus)
      VCAP::Component.register(
          :type => 'CloudController',
          :host => @config[:bind_address],
          :index => @config[:index],
          :config => @config,
          :nats => message_bus,
          :logger => logger,
          :log_counter => @log_counter
      )
    end
  end
end
