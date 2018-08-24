namespace :jobs do
  desc 'Clear the delayed_job queue.'
  task :clear do
    RakeConfig.context = :worker
    BackgroundJobEnvironment.new(RakeConfig.config).setup_environment do
      Delayed::Job.delete_all
    end
  end

  desc 'Start a delayed_job worker that works on jobs that require access to local resources.'

  task :local, [:name] do |t, args|
    RakeConfig.context = :api

    CloudController::DelayedWorker.new(queues: [VCAP::CloudController::Jobs::LocalQueue.new(RakeConfig.config).to_s],
                                       name: args.name).start_working
  end

  desc 'Start a delayed_job worker.'
  task :generic, [:name] do |t, args|
    RakeConfig.context = :worker
    queues = [
      'cc-generic',
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
      BackgroundJobEnvironment.new(config).setup_environment
      logger = Steno.logger('cc-worker')
      logger.info("Starting job with options #{@queue_options}")
      if config.get(:loggregator) && config.get(:loggregator, :router)
        VCAP::Loggregator.emitter = LoggregatorEmitter::Emitter.new(config.get(:loggregator, :router), 'cloud_controller', 'API', config.get(:index))
        VCAP::Loggregator.logger = logger
      end
      Delayed::Worker.destroy_failed_jobs = false
      Delayed::Worker.max_attempts = 3
      Delayed::Worker.logger = logger
      worker = Delayed::Worker.new(@queue_options)
      worker.name = @queue_options[:worker_name]
      worker.start
    end
  end
end
