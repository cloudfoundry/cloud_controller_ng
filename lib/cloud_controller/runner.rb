# Copyright (c) 2009-2012 VMware, Inc.

require "steno"
require "optparse"
require "vcap/uaa_util"
require File.expand_path("../message_bus.rb", __FILE__)

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
          @run_migrations = true
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

      run_migrations = @run_migrations
      config = @config.dup

      if run_migrations
        VCAP::CloudController::Models::QuotaDefinition.populate_from_config(config)
        VCAP::CloudController::Models::Stack.populate
      end

      config[:system_domains].each do |name|
        VCAP::CloudController::Models::Domain.find_or_create_shared_domain(name)
      end

      VCAP::CloudController::Models::Domain.default_serving_domain_name = config[:system_domains].first

      app = create_app(config)
      start_thin_server(app, config)
    end

    def trap_signals
      %w(TERM INT QUIT).each do |signal|
        trap(signal) do
          @thin_server.stop! if @thin_server
          EM.stop
        end
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

    def start_cloud_controller
      create_pidfile

      setup_logging
      setup_db

      @config[:bind_address] = VCAP.local_ip(@config[:local_route])
      VCAP::CloudController::Config.configure(@config)
    end

    def create_app(config)
      token_decoder = VCAP::UaaTokenDecoder.new(config[:uaa])

      Rack::Builder.new do
        use Rack::CommonLogger

        VCAP::CloudController::MessageBus.instance.register_components
        VCAP::CloudController::MessageBus.instance.register_routes

        VCAP::CloudController::DeaClient.run
        VCAP::CloudController::AppStager.run

        VCAP::CloudController::LegacyBulk.register_subscription
        VCAP::CloudController.health_manager_respondent = \
          VCAP::CloudController::HealthManagerRespondent.new(config)
        VCAP::CloudController.dea_respondent = \
          VCAP::CloudController::DeaRespondent.new(config, VCAP::CloudController::MessageBus.instance)
        map "/" do
          run VCAP::CloudController::Controller.new(config, token_decoder)
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
  end
end
