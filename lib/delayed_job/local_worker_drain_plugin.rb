require 'jobs/queues'

# Local workers process jobs that require access to local filesystem resources (e.g. buildpack, droplet,
# and package uploads via nginx). The 'delayed_job' gem's default SIGTERM handler calls stop(), which
# exits the worker after the current job finishes - leaving the rest of the queue unprocessed.
# This plugin replaces the gem's SIGTERM handler for local workers so that all remaining jobs in the
# queue are worked off before the worker exits, ensuring no jobs are left dangling when draining.
class LocalWorkerDrainPlugin < Delayed::Plugin
  callbacks do |lifecycle|
    lifecycle.before(:execute) do |worker|
      next unless worker.class.queues.length == 1 && VCAP::CloudController::Jobs::Queues.local?(worker.class.queues.first)

      trap('TERM') do
        Thread.new { worker.say 'Exiting...' }
        worker.class.exit_on_complete = true
      end
    end
  end
end

Delayed::Worker.plugins << LocalWorkerDrainPlugin
