require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class TaskListFetcher < BaseListFetcher
    class << self
      def fetch_for_spaces(message:, space_guids:)
        app_dataset = AppModel.select(:id).where(space_guid: space_guids)
        filter(message).where(app: filter_app_dataset(message, app_dataset))
      end

      def fetch_all(message:)
        app_dataset = AppModel.select(:id)
        filter(message).where(app: filter_app_dataset(message, app_dataset))
      end

      def fetch_for_app(message:)
        app_dataset = AppModel.where(guid: message.app_guid)
        app = app_dataset.first
        return nil unless app

        if message.requested?(:organization_guids) || message.requested?(:space_guids) || message.requested?(:app_guids)
          [app, filter(message).where(app: filter_app_dataset(message, app_dataset))]
        else
          [app, filter_task_dataset(message, TaskModel.dataset).where(app_guid: message.app_guid).qualify]
        end
      end

      private

      def filter(message)
        task_dataset = TaskModel.dataset
        task_dataset = filter_task_dataset(message, task_dataset)

        super(message, task_dataset, TaskModel)
      end

      def filter_app_dataset(message, app_dataset)
        if message.requested?(:space_guids)
          app_dataset = app_dataset.where(space_guid: message.space_guids)
        end
        if message.requested?(:organization_guids)
          app_dataset = app_dataset.where(space_guid: Organization.where(guid: message.organization_guids).map(&:spaces).flatten.map(&:guid))
        end
        if message.requested?(:app_guids)
          app_dataset = app_dataset.where(guid: message.app_guids)
        end
        app_dataset
      end

      def filter_task_dataset(message, task_dataset)
        if message.requested?(:names)
          task_dataset = task_dataset.where(name: message.names)
        end

        if message.requested?(:states)
          task_dataset = task_dataset.where(state: message.states)
        end

        if message.requested?(:sequence_ids)
          task_dataset = task_dataset.where(sequence_id: message.sequence_ids)
        end

        if message.requested?(:label_selector)
          task_dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: TaskLabelModel,
            resource_dataset: task_dataset,
            requirements: message.requirements,
            resource_klass: TaskModel
          )
        end

        BaseListFetcher.filter(message, task_dataset, TaskModel)
      end
    end
  end
end
