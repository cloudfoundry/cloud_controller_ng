# Copyright (c) 2009-2012 VMware, Inc.

require "steno"
require "optparse"
require "vcap/uaa_util"
require File.expand_path("../message_bus.rb", __FILE__)
require File.expand_path("../seeds", __FILE__)

module VCAP::CloudController
  class Runner
    def initialize(argv)
      @argv = argv

      # default to production. this may be overriden during opts parsing
      ENV["RACK_ENV"] = "production"
      @config_file = File.expand_path("../../../config/cloud_controller.yml", __FILE__)
      parse_options!
      parse_config
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
      @config = VCAP::CloudController::Config.from_file(@config_file)
    rescue Membrane::SchemaValidationError => ve
      puts "ERROR: There was a problem validating the supplied config: #{ve}"
      exit 1
    rescue => e
      puts "ERROR: Failed loading config from file '#{@config_file}': #{e}"
      exit 1
    end

    def create_pidfile
      begin
        pid_file = VCAP::PidFile.new(@config[:pid_filename])
        pid_file.unlink_at_exit
      rescue => e
        puts "ERROR: Can't create pid file #{@config[:pid_filename]}"
        exit 1
      end
    end

    def setup_logging
      steno_config = Steno::Config.to_config_hash(@config[:logging])
      steno_config[:context] = Steno::Context::ThreadLocal.new
      Steno.init(Steno::Config.new(steno_config))
    end

    def setup_db
      logger.info "db config #{@config[:db]}"
      db_logger = Steno.logger("cc.db")
      DB.connect(db_logger, @config[:db])
    end

    def development?
      @development ||= false
    end

    def run!
      start_cloud_controller
      config = @config.dup

      Seeds.write_seed_data(config) if @insert_seed_data
      app = create_app(config)

      start_thin_server(app, config)
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
      message_bus.unregister_routes do
        stop_thin_server
        EM.stop
      end
    end

    private

    def start_cloud_controller
      create_pidfile

      setup_logging
      setup_db

      @config[:bind_address] = VCAP.local_ip(@config[:local_route])
      VCAP::CloudController::Config.configure(@config)
    end

    def create_app(config)
      token_decoder = VCAP::UaaTokenDecoder.new(config[:uaa])

      mbus = message_bus

      Rack::Builder.new do
        use Rack::CommonLogger

        mbus.register_components
        mbus.register_routes

        DeaClient.run
        AppStager.run

        LegacyBulk.register_subscription

        VCAP::CloudController.health_manager_respondent =
          HealthManagerRespondent.new(config)

        VCAP::CloudController.dea_respondent = DeaRespondent.new(mbus)

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

    def message_bus
      VCAP::CloudController::MessageBus.instance
    end
  end
end
