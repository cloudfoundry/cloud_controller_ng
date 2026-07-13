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
    require 'delayed_job/local_worker_drain_plugin'
    puts RUBY_DESCRIPTION
    queue = VCAP::CloudController::Jobs::Queues.local(RakeConfig.config).to_s
    args.with_defaults(name: queue)

    RakeConfig.context = :api

    CloudController::DelayedWorker.new(queues: [queue],
                                       name: args.name).start_working
  end

  desc 'Start a delayed_job worker.'
  task :generic, %i[name num_threads thread_grace_period_seconds] => :environment do |_t, args|
    require 'cloud_controller/clock/scheduler'
    puts RUBY_DESCRIPTION
    args.with_defaults(name: ENV.fetch('HOSTNAME', nil))
    args.with_defaults(num_threads: nil)
    args.with_defaults(thread_grace_period_seconds: nil)

    queues = [
      VCAP::CloudController::Jobs::Queues.generic,
      *VCAP::CloudController::Scheduler.queue_names
    ]

    require 'cloud_controller/metrics/custom_process_id'
    require 'cloud_controller/execution_context'
    VCAP::CloudController::ExecutionContext::CC_WORKER.set_rake_context
    VCAP::CloudController::ExecutionContext::CC_WORKER.set_process_type_env

    publish_metrics = RakeConfig.config.get(:publish_metrics)

    CloudController::DelayedWorker.new(queues: queues,
                                       name: args.name,
                                       num_threads: args.num_threads,
                                       thread_grace_period_seconds: args.thread_grace_period_seconds,
                                       publish_metrics: publish_metrics).start_working
  end
end
