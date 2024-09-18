require 'delayed_job/threaded_worker'

class CloudController::DelayedWorker
  def initialize(options)
    @queue_options = {
      min_priority: ENV.fetch('MIN_PRIORITY', nil),
      max_priority: ENV.fetch('MAX_PRIORITY', nil),
      queues: options.fetch(:queues),
      worker_name: options[:name],
      quiet: true
    }
  end

  def start_working
    config = RakeConfig.config
    BackgroundJobEnvironment.new(config).setup_environment(readiness_port)

    logger = Steno.logger('cc-worker')
    logger.info("Starting job with options #{@queue_options}")

    setup_app_log_emitter(config, logger)
    Delayed::Worker.destroy_failed_jobs = false
    Delayed::Worker.max_attempts = 3
    Delayed::Worker.max_run_time = config.get(:jobs, :global, :timeout_in_seconds) + 1
    Delayed::Worker.logger = logger
    num_worker_threads = config.get(:jobs, :number_of_worker_threads)
    if num_worker_threads.nil?
      worker = Delayed::Worker.new(@queue_options)
    else
      require 'delayed_job/plugin_threaded_worker_patch'
      worker = Delayed::ThreadedWorker.new(num_worker_threads, @queue_options)
    end
    worker.name = @queue_options[:worker_name]
    worker.start
  end

  private

  def setup_app_log_emitter(config, logger)
    VCAP::AppLogEmitter.fluent_emitter = fluent_emitter(config) if config.get(:fluent)
    if config.get(:loggregator) && config.get(
      :loggregator, :router
    )
      VCAP::AppLogEmitter.emitter = LoggregatorEmitter::Emitter.new(config.get(:loggregator, :router), 'cloud_controller', 'API',
                                                                    config.get(:index))
    end

    VCAP::AppLogEmitter.logger = logger
  end

  def fluent_emitter(config)
    VCAP::FluentEmitter.new(Fluent::Logger::FluentLogger.new(nil,
                                                             host: config.get(:fluent, :host) || 'localhost',
                                                             port: config.get(:fluent, :port) || 24_224))
  end

  def readiness_port
    return unless is_first_generic_worker_on_machine?

    RakeConfig.config.get(:readiness_port, :cloud_controller_worker)
  end

  def is_first_generic_worker_on_machine?
    RakeConfig.context != :api && ENV['INDEX']&.to_i == 1
  end
end
