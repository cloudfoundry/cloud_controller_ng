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

        summary.routes = Route.
                         dataset.
                         count

        summary.service_instances = ServiceInstance.
                                    dataset.
                                    where(is_gateway_service: false).
                                    count

        summary.reserved_ports = Route.
                                 join(:domains, id: :domain_id).
                                 where { (Sequel[:domains][:router_group_guid] !~ nil) & (Sequel[:routes][:port] !~ nil) }.
                                 count

        summary.domains = Domain.
                          dataset.
                          where { Sequel[:owning_organization_id] !~ nil }.
                          count

        summary.per_app_tasks = TaskModel.
                                dataset.
                                where(state: [TaskModel::PENDING_STATE, TaskModel::RUNNING_STATE]).
                                count

        summary.service_keys = ServiceKey.
                               dataset.
                               count

        summary
      end

      class Summary
        attr_accessor :started_instances, :memory_in_mb, :routes, :service_instances, :reserved_ports, :domains, :per_app_tasks, :service_keys
      end
    end
  end
end
