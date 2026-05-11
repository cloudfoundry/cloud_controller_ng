require 'delayed_job/quit_trap'
require 'delayed_job/delayed_worker'

namespace :jobs do
  desc 'Interactive job stepper. Processes jobs one at a time, polls for new ones. Useful for debugging and demos.'
  task :step, [:name] => :environment do |_t, args|
    args.with_defaults(name: 'cc-step')

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

    RakeConfig.context = :worker
    config = RakeConfig.config
    BackgroundJobEnvironment.new(config).setup_environment(nil)

    Delayed::Worker.destroy_failed_jobs = false
    Delayed::Worker.max_attempts = 3
    Delayed::Worker.max_run_time = config.get(:jobs, :global, :timeout_in_seconds) + 1
    Delayed::Worker.logger = Steno.logger('cc-worker')

    worker = Delayed::Worker.new(queues: queues, quiet: false)
    worker.name = args.name

    poll_interval = 30
    fast_poll_interval = 2

    pending = Delayed::Job.where(failed_at: nil).where { run_at <= Sequel::CURRENT_TIMESTAMP }.count
    puts "Ready. #{pending} runnable job(s). Enter=1, N=N, a=auto (#{poll_interval}s), f=fast auto (#{fast_poll_interval}s), q=quit"

    auto_mode = false
    current_poll_interval = poll_interval
    fast_mode = false

    loop do
      if auto_mode
        success, failure = worker.work_off(1)
        if success + failure == 0
          pending = Delayed::Job.where(failed_at: nil).count
          scheduled = Delayed::Job.where(failed_at: nil).where { run_at > Sequel::CURRENT_TIMESTAMP }.count
          status = pending.zero? ? 'No jobs.' : "#{pending} pending (#{scheduled} scheduled future)"
          print "\r\e[K[#{fast_mode ? 'fast' : 'auto'}] #{status} Polling in #{current_poll_interval}s... (Enter to stop) "
          ready = $stdin.wait_readable(current_poll_interval)
          if ready
            $stdin.gets
            auto_mode = false
            fast_mode = false
            puts "\nStopped."
            pending = Delayed::Job.where(failed_at: nil).where { run_at <= Sequel::CURRENT_TIMESTAMP }.count
            puts "#{pending} runnable job(s). Enter=1, N=N, a=auto, f=fast, q=quit"
          end
        else
          puts "[#{fast_mode ? 'fast' : 'auto'}] Processed: success=#{success} failure=#{failure}"
        end
      else
        print '> '
        input = $stdin.gets&.strip
        break if input.nil? || input == 'q'

        if input == 'a'
          auto_mode = true
          fast_mode = false
          current_poll_interval = poll_interval
          puts "Auto mode (#{poll_interval}s poll). Enter to stop."
          next
        end

        if input == 'f'
          auto_mode = true
          fast_mode = true
          current_poll_interval = fast_poll_interval
          puts "Fast mode (#{fast_poll_interval}s poll). Enter to stop."
          next
        end

        count = input.empty? ? 1 : input.to_i
        count = 1 if count < 1

        success, failure = worker.work_off(count)
        if success + failure == 0
          puts 'No jobs ready to run.'
        else
          puts "Processed #{success + failure} job(s): success=#{success} failure=#{failure}"
        end

        pending = Delayed::Job.where(failed_at: nil).where { run_at <= Sequel::CURRENT_TIMESTAMP }.count
        puts "#{pending} runnable job(s) remaining."
      end
    end
  end

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
