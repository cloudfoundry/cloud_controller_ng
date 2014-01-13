namespace :jobs do
  desc "Clear the delayed_job queue."
  task :clear do
    BackgroundJobEnvironment.new(config).setup_environment
    Delayed::Job.delete_all
  end

  desc "Start a delayed_job worker."
  task :work do
    queue_options = {
      min_priority: ENV['MIN_PRIORITY'],
      max_priority: ENV['MAX_PRIORITY'],
      queues: (ENV['QUEUES'] || ENV['QUEUE'] || '').split(','),
      quiet: false
    }
    BackgroundJobEnvironment.new(config).setup_environment
    Delayed::Worker.destroy_failed_jobs = false
    logger = Steno.logger("cc-worker")
    logger.info("Starting job with options #{queue_options}")
    Delayed::Worker.new(queue_options).start
  end
end
