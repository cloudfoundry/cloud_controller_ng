require 'delayed_job/quit_trap'
require 'delayed_job/delayed_worker'

namespace :jobs do
  desc 'Clear the delayed_job queue.'
  task clear: :environment do
    RakeConfig.context = :worker
    BackgroundJobEnvironment.new(RakeConfig.config).setup_environment(RakeConfig.config.get(:readiness_port,
                                                                                            :cloud_controller_worker)) do
      Delayed::Job.delete_all
    end
  end

  desc 'Clear pending locks for the current delayed worker.'
  task :clear_pending_locks, [:name] => :environment do |_t, args|
    puts RUBY_DESCRIPTION
    puts "Clearing pending locks for worker: #{args.name}"
    args.with_defaults(name: ENV.fetch('HOSTNAME', nil))

    RakeConfig.context = :worker

    CloudController::DelayedWorker.new(queues: [],
                                       name: args.name).clear_locks!
  end

  desc 'Start a delayed_job worker that works on jobs that require access to local resources.'

  task :local, [:name] => :environment do |_t, args|
    puts RUBY_DESCRIPTION
    queue = VCAP::CloudController::Jobs::Queues.local(RakeConfig.config).to_s
    args.with_defaults(name: queue)

    RakeConfig.context = :api

    CloudController::DelayedWorker.new(queues: [queue],
                                       name: args.name).start_working
  end

  desc 'Start a delayed_job worker.'
  task :generic, %i[name num_threads thread_grace_period_seconds] => :environment do |_t, args|
    puts RUBY_DESCRIPTION
    args.with_defaults(name: ENV.fetch('HOSTNAME', nil))
    args.with_defaults(num_threads: nil)
    args.with_defaults(thread_grace_period_seconds: nil)

    RakeConfig.context = :worker
    queues = [
      VCAP::CloudController::Jobs::Queues.generic,
      'app_usage_events',
      'audit_events',
      'failed_jobs',
      'service_operations_initial_cleanup',
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
      'prune_excess_app_revisions'
    ]

    ENV['PROCESS_TYPE'] = 'cc-worker'

    CloudController::DelayedWorker.new(queues: queues,
                                       name: args.name,
                                       num_threads: args.num_threads,
                                       thread_grace_period_seconds: args.thread_grace_period_seconds,
                                       publish_metrics: true).start_working
  end
end
