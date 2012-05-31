# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class Runner
    def initialize(argv)
      @argv = argv

      # default to production. this may be overriden during opts parsing
      ENV["RACK_ENV"] = "production"
      @config_file = File.expand_path("../../../config/cloud_controller.yml",
                                      __FILE__)
      parse_options!
      parse_config

      create_pidfile
      setup_db
      setup_logging
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
    rescue VCAP::JsonSchema::ValidationError => ve
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
      VCAP::Logging.setup_from_config(@config[:logging])
    end

    def setup_db
      db_logger = VCAP::Logging.logger("cc.db")
      DB.connect(db_logger, @config[:db])
    end

    def run!
      db = setup_db
      run_migrations = @run_migrations
      development = @development
      config = @config

      DB.apply_migrations(db) if run_migrations

      @thin_server = Thin::Server.new("0.0.0.0", @config[:port],
                                      :signals => false) do
        use Rack::CommonLogger
        map "/" do
          DB.apply_migrations(db) if (run_migrations && development)
          run VCAP::CloudController::Controller.new(config)
        end
      end

      trap_signals
      @thin_server.threaded = true
      @thin_server.start!
    end

    def trap_signals
      ["TERM", "INT", "QUIT"].each do |signal|
        trap(signal) do
          @thin_server.stop! if @thin_server
          EM.stop
        end
      end
    end
  end
end
