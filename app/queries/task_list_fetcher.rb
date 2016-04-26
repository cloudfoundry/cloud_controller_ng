module VCAP::CloudController
  class TaskListFetcher
    def fetch_for_spaces(message:, space_guids:)
      pagination_options = message.pagination_options
      app_dataset = AppModel.select(:id).where(space_guid: space_guids)
      SequelPaginator.new.get_page(filter(message: message, app_dataset: app_dataset), pagination_options)
    end

    def fetch_all(message:)
      pagination_options = message.pagination_options
      app_dataset = AppModel.select(:id)
      SequelPaginator.new.get_page(filter(message: message, app_dataset: app_dataset), pagination_options)
    end

    def fetch_for_app(message:)
      pagination_options = message.pagination_options
      app_dataset = AppModel.where(guid: message.app_guid).eager(:space, space: :organization)
      app = app_dataset.first
      return nil unless app
      [app, SequelPaginator.new.get_page(filter(message: message, app_dataset: app_dataset), pagination_options)]
    end

    private

    def filter(message:, app_dataset:)
      task_dataset = TaskModel.dataset
      filter_task_dataset(message, task_dataset).where(app: filter_app_dataset(message, app_dataset))
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

      if message.requested?(:guids)
        task_dataset = task_dataset.where(guid: message.guids)
      end

      task_dataset
    end
  end
end
