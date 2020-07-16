namespace :jobs do
  desc 'Clear the delayed_job queue.'
  task :clear do
    RakeConfig.context = :worker
    BackgroundJobEnvironment.new(RakeConfig.config).setup_environment(RakeConfig.config.get(:readiness_port,
                                                                                            :cloud_controller_worker)) do
      Delayed::Job.delete_all
    end
  end

  desc 'Start a delayed_job worker that works on jobs that require access to local resources.'

  task :local, [:name] do |t, args|
    queue = VCAP::CloudController::Jobs::Queues.local(RakeConfig.config).to_s
    args.with_defaults(name: queue)

    RakeConfig.context = :api

    CloudController::DelayedWorker.new(queues: [queue],
                                       name: args.name).start_working
  end

  desc 'Start a delayed_job worker.'
  task :generic, [:name] do |t, args|
    args.with_defaults(name: ENV['HOSTNAME'])

    RakeConfig.context = :worker
    queues = [
      VCAP::CloudController::Jobs::Queues.generic,
      'app_usage_events',
      'audit_events',
      'failed_jobs',
      'service_usage_events',
      'completed_tasks',
      'expired_blob_cleanup',
      'expired_resource_cleanup',
      'expired_orphaned_blob_cleanup',
      'orphaned_blobs_cleanup',
      'pollable_job_cleanup',
      'pending_droplets',
      'pending_builds',
      'prune_completed_deployments',
      'prune_completed_builds',
      'prune_excess_app_revisions',
      'request_counts_cleanup',
    ]

    CloudController::DelayedWorker.new(queues: queues,
                                       name: args.name).start_working
  end

  class CloudController::DelayedWorker
    def initialize(options)
      @queue_options = {
        min_priority: ENV['MIN_PRIORITY'],
        max_priority: ENV['MAX_PRIORITY'],
        queues: options.fetch(:queues),
        worker_name: options[:name],
        quiet: true,
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
      Delayed::Worker.logger = logger
      worker = Delayed::Worker.new(@queue_options)
      worker.name = @queue_options[:worker_name]
      worker.start
    end

    private

    def setup_app_log_emitter(config, logger)
      VCAP::AppLogEmitter.fluent_emitter = fluent_emitter(config) if config.get(:fluent)
      if config.get(:loggregator) && config.get(:loggregator, :router)
        VCAP::AppLogEmitter.emitter = LoggregatorEmitter::Emitter.new(config.get(:loggregator, :router), 'cloud_controller', 'API', config.get(:index))
      end

      VCAP::AppLogEmitter.logger = logger
    end

    def fluent_emitter(config)
      VCAP::FluentEmitter.new(Fluent::Logger::FluentLogger.new(nil,
        host: config.get(:fluent, :host) || 'localhost',
        port: config.get(:fluent, :port) || 24224,
      ))
    end

    def readiness_port
      if is_first_generic_worker_on_machine?
        RakeConfig.config.get(:readiness_port, :cloud_controller_worker)
      end
    end

    def is_first_generic_worker_on_machine?
      RakeConfig.context != :api && ENV['INDEX']&.to_i == 1
    end
  end
end
