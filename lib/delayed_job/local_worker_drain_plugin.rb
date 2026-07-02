# Replaces the default SIGTERM handler for local workers to drain all remaining jobs before exiting.
class LocalWorkerDrainPlugin < Delayed::Plugin
  callbacks do |lifecycle|
    lifecycle.before(:execute) do |worker|
      trap('TERM') do
        Thread.new { worker.say 'Draining: will exit after finishing remaining jobs' }
        worker.class.exit_on_complete = true
      end
    end
  end
end

Delayed::Worker.plugins << LocalWorkerDrainPlugin
