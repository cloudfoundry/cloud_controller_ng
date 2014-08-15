namespace :jobs do
  desc "Clear the delayed_job queue."
  task :clear do
    BackgroundJobEnvironment.new(config).setup_environment
    Delayed::Job.delete_all
  end

  desc "Start a delayed_job worker that works on jobs that require access to local resources."
  task :local do
    CloudController::DelayedWorker.new(queues: [VCAP::CloudController::Jobs::LocalQueue.new(config).to_s]).start_working
  end

  desc "Start a delayed_job worker."
  task :generic do
    CloudController::DelayedWorker.new(queues: ['cc-generic']).start_working
  end

  class CloudController::DelayedWorker
    def initialize(options)
      @queue_options = {
        min_priority: ENV['MIN_PRIORITY'],
        max_priority: ENV['MAX_PRIORITY'],
        queues: options.fetch(:queues),
        quiet: false
      }
    end

    def start_working
      BackgroundJobEnvironment.new(config).setup_environment
      Delayed::Worker.destroy_failed_jobs = false
      Delayed::Worker.max_attempts = 3
      logger = Steno.logger("cc-worker")
      logger.info("Starting job with options #{@queue_options}")
      Delayed::Worker.new(@queue_options).start
    end
  end
end
