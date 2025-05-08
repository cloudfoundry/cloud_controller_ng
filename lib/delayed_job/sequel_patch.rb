require 'delayed/backend/sequel'

module Delayed
  module Backend
    module Sequel
      class Job
        # monkey patch to allow explicit configuration of job lock method
        def self.reserve(worker, max_run_time=Worker.max_run_time)
          ds = ready_to_run(worker.name, max_run_time)

          ds = ds.filter(::Sequel.lit('priority >= ?', Worker.min_priority)) if Worker.min_priority
          ds = ds.filter(::Sequel.lit('priority <= ?', Worker.max_priority)) if Worker.max_priority
          ds = ds.filter(queue: Worker.queues) if Worker.queues.any?
          ds = ds.by_priority

          if Worker.read_ahead > 0
            lock_with_read_ahead(ds, worker)
          else
            lock_with_for_update(ds, worker)
          end
        end
      end
    end
  end
end
