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
    return unless options[:num_threads] && options[:num_threads].to_i > 0

    @queue_options[:num_threads] = options[:num_threads].to_i
    @queue_options[:grace_period_seconds] = options[:thread_grace_period_seconds].to_i if options[:thread_grace_period_seconds] && options[:thread_grace_period_seconds].to_i > 0
  end

  def start_working
    config = RakeConfig.config
    BackgroundJobEnvironment.new(config).setup_environment(readiness_port)

    logger = Steno.logger('cc-worker')
    logger.info("Starting job with options #{@queue_options}")
    setup_app_log_emitter(config, logger)

    worker = get_initialized_delayed_worker(config, logger)
    worker.start
  end

  def clear_locks!
    config = RakeConfig.config
    BackgroundJobEnvironment.new(config).setup_environment(readiness_port)

    logger = Steno.logger('cc-worker-clear-locks')
    logger.info("Clearing pending locks with options {#{@queue_options.map { |k, v| "#{k}: #{v.inspect}" }.join(', ')}}")
    setup_app_log_emitter(config, logger)

    worker = get_initialized_delayed_worker(config, logger)
    Delayed::Job.clear_locks!(worker.name)

    # Clear locks for all threads when using a threaded worker
    worker.names_with_threads.each { |name| Delayed::Job.clear_locks!(name) } if worker.respond_to?(:names_with_threads)
  end

  private

  def get_initialized_delayed_worker(config, logger)
    Delayed::Worker.destroy_failed_jobs = false
    Delayed::Worker.max_attempts = 3
    Delayed::Worker.max_run_time = config.get(:jobs, :global, :timeout_in_seconds) + 1
    Delayed::Worker.logger = logger

    unless @queue_options[:num_threads].nil?
      # Dynamically alias Delayed::Worker to ThreadedWorker to ensure plugins etc are working correctly
      Delayed.module_eval do
        remove_const(:Worker) if const_defined?(:Worker)
        const_set(:Worker, Delayed::ThreadedWorker)
      end
    end

    worker = Delayed::Worker.new(@queue_options)
    worker.name = @queue_options[:worker_name]
    worker
  end

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
