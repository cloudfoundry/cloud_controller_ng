module VCAP::CloudController
  class TaskListFetcher
    def fetch_for_spaces(pagination_options:, message:, space_guids:)
      app_dataset = AppModel.select(:id).where(space_guid: space_guids)
      SequelPaginator.new.get_page(filter(message: message, app_dataset: app_dataset), pagination_options)
    end

    def fetch_all(pagination_options:, message:)
      app_dataset = AppModel.select(:id)
      SequelPaginator.new.get_page(filter(message: message, app_dataset: app_dataset), pagination_options)
    end

    def fetch_for_app(pagination_options:, message:, app_guid:)
      app_dataset = AppModel.where(guid: app_guid).eager(:space, space: :organization)
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
