# Class 'Worker' in the 'delayed_job' gem only handles SIGTERM & SIGINT which result in a graceful shutdown
# This monkey patch extends `start()` to also handle SIGQUIT.
# Could be replaced by https://github.com/collectiveidea/delayed_job/pull/900

module QuitTrap
  def start
    trap('QUIT') do
      Thread.new { say 'Exiting...' }
      stop
    end

    super
  end
end

module Delayed
  class Worker
    prepend QuitTrap
  end
end
