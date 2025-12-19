require 'steno'
require 'optparse'
require 'cloud_controller/uaa/uaa_token_decoder'
require 'cloud_controller/uaa/uaa_verification_keys'
require 'app_log_emitter'
require 'loggregator_emitter'
require 'fluent_emitter'
require 'cloud_controller/rack_app_builder'
require 'cloud_controller/metrics/periodic_updater'
require 'cloud_controller/metrics/request_metrics'
require 'cloud_controller/logs/request_logs'
require 'cloud_controller/telemetry_logger'
require 'cloud_controller/secrets_fetcher'
require 'cloud_controller/runners/puma_runner'
require 'cloud_controller/api_metrics_webserver'
require 'cloud_controller/execution_context'
require 'prometheus/client/data_stores/direct_file_store'
require 'prometheus/middleware/exporter'

module VCAP::CloudController
  class Runner
    attr_reader :config, :config_file, :secrets_file

    def initialize(argv)
      @argv = argv

      # default to production. this may be overridden during opts parsing
      ENV['NEW_RELIC_ENV'] ||= 'production'

      parse_options!
      secrets_hash = parse_secrets
      parse_config(secrets_hash)

      # DB connection metrics have a label to determine whether the process accessing the connection is the
      # main or a worker process. We need to set this env variable before `setup_db` otherwise the main process
      # will show up twice in the metrics as main and worker.
      VCAP::CloudController::ExecutionContext::API_PUMA_MAIN.set_process_type_env

      setup_cloud_controller

      request_logs = VCAP::CloudController::Logs::RequestLogs.new(Steno.logger('cc.api'))

      request_metrics = VCAP::CloudController::Metrics::RequestMetrics.new(CloudController::DependencyLocator.instance.statsd_updater,
                                                                           CloudController::DependencyLocator.instance.prometheus_updater)
      builder = RackAppBuilder.new
      app     = builder.build(@config, request_metrics, request_logs)

      @server = VCAP::CloudController::PumaRunner.new(@config, app, logger, periodic_updater, request_logs)
    end

    def logger
      setup_logging
      @logger ||= Steno.logger('cc.runner')
    end

    def options_parser
      @options_parser ||= OptionParser.new do |opts|
        opts.on('-c', '--config [ARG]', 'Configuration File') do |opt|
          @config_file = opt
        end
        opts.on('-s', '--secrets [ARG]', 'Secrets File') do |opt|
          @secrets_file = opt
        end
      end
    end

    def parse_options!
      options_parser.parse!(@argv)
      raise 'Missing config' if @config_file.blank?
    rescue StandardError
      raise options_parser.to_s
    end

    def parse_secrets
      return {} unless secrets_file

      SecretsFetcher.fetch_secrets_from_file(secrets_file)
    rescue StandardError => e
      raise "ERROR: Failed loading secrets from file '#{secrets_file}': #{e}"
    end

    def parse_config(secrets_hash)
      @config = Config.load_from_file(config_file, context: :api, secrets_hash: secrets_hash)
    rescue Membrane::SchemaValidationError => e
      raise "ERROR: There was a problem validating the supplied config: #{e}"
    rescue StandardError => e
      raise "ERROR: Failed loading config from file '#{config_file}': #{e}"
    end

    def run!
      create_pidfile
      @server.start!
    end

    private

    def setup_cloud_controller
      setup_metrics
      setup_logging
      setup_telemetry_logging
      setup_db
      setup_blobstore
      @config.configure_components

      setup_app_log_emitter
      @config.set(:external_host, VCAP::HostSystem.new.local_ip(@config.get(:local_route)))
    end

    def create_pidfile
      pid_file = VCAP::PidFile.new(@config.get(:pid_filename))
      pid_file.unlink_at_exit
    rescue StandardError
      raise "ERROR: Can't create pid file #{@config.get(:pid_filename)}"
    end

    def setup_metrics
      return if @setup_metrics

      @setup_metrics = true

      return unless @config.get(:webserver) == 'puma'

      prometheus_dir = File.join(@config.get(:directories, :tmpdir), 'prometheus')
      FileUtils.mkdir_p(prometheus_dir)

      # Resetting metrics on startup
      Dir["#{prometheus_dir}/*.bin"].each do |file_path|
        File.unlink(file_path)
      end

      Prometheus::Client.config.data_store = Prometheus::Client::DataStores::DirectFileStore.new(dir: prometheus_dir)

      Thread.new do
        VCAP::CloudController::ApiMetricsWebserver.new.start(@config)
      end
    end

    def setup_logging
      return if @setup_logging

      @setup_logging = true

      StenoConfigurer.new(@config.get(:logging)).configure do |steno_config_hash|
        steno_config_hash[:sinks] << CloudController::DependencyLocator.instance.log_counter
      end
    end

    def setup_telemetry_logging
      return if @setup_telemetry_logging

      @setup_telemetry_logging = true

      telemetry_log_path = @config.get(:telemetry_log_path)
      TelemetryLogger.init(ActiveSupport::Logger.new(telemetry_log_path)) unless telemetry_log_path.nil?
    end

    def setup_db
      db_logger = Steno.logger('cc.db')
      db_config = @config.get(:db)

      if @config.get(:webserver) == 'puma'
        max_db_connections_per_process = @config.get(:puma, :max_db_connections_per_process)
        db_config.merge!(max_connections: max_db_connections_per_process) unless max_db_connections_per_process.nil?
      end

      DB.load_models(db_config, db_logger)
    end

    def setup_blobstore
      CloudController::DependencyLocator.instance.droplet_blobstore.ensure_bucket_exists
      CloudController::DependencyLocator.instance.package_blobstore.ensure_bucket_exists
      CloudController::DependencyLocator.instance.global_app_bits_cache.ensure_bucket_exists
      CloudController::DependencyLocator.instance.buildpack_blobstore.ensure_bucket_exists
    end

    def setup_app_log_emitter
      VCAP::AppLogEmitter.fluent_emitter = fluent_emitter if @config.get(:fluent)

      if @config.get(:loggregator) && @config.get(
        :loggregator, :router
      )
        VCAP::AppLogEmitter.emitter = LoggregatorEmitter::Emitter.new(@config.get(:loggregator, :router), 'cloud_controller', 'API',
                                                                      @config.get(:index))
      end

      VCAP::AppLogEmitter.logger = logger
    end

    def fluent_emitter
      VCAP::FluentEmitter.new(Fluent::Logger::FluentLogger.new(nil,
                                                               host: @config.get(:fluent, :host) || 'localhost',
                                                               port: @config.get(:fluent, :port) || 24_224))
    end

    def periodic_updater
      CloudController::DependencyLocator.instance.periodic_updater
    end
  end
end
