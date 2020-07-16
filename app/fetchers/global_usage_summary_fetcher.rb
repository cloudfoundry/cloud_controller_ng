module VCAP::CloudController
  class GlobalUsageSummaryFetcher
    class << self
      def summary
        summary = Summary.new

        summary.started_instances = ProcessModel.
                                    dataset.
                                    where(state: ProcessModel::STARTED).
                                    sum(:instances) || 0

        running_task_memory = TaskModel.
                              dataset.
                              where(state: TaskModel::RUNNING_STATE).
                              sum(:memory_in_mb) || 0

        started_app_memory = ProcessModel.
                             dataset.
                             where(state: ProcessModel::STARTED).
                             sum(Sequel.*(:memory, :instances)) || 0

        summary.memory_in_mb = running_task_memory + started_app_memory

        summary
      end

      class Summary
        attr_accessor :started_instances, :memory_in_mb
      end
    end
  end
end
