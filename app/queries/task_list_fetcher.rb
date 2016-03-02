module VCAP::CloudController
  class TaskListFetcher
    def fetch(pagination_options, message, space_guids, app_guid)
      # TODO: have dataset filter on space_guids
      dataset = TaskModel.select_all(:tasks)
      filter(pagination_options, message, dataset, space_guids, app_guid)
    end

    private

    def filter(pagination_options, message, dataset, space_guids, app_guid)
      app_dataset = nil

      if space_guids
        app_dataset ||= AppModel.select(:id)
        app_dataset = app_dataset.where(space_guid: space_guids)
      end

      if app_guid
        app_dataset ||= AppModel.select(:id)
        app_dataset = app_dataset.where(guid: app_guid)
      end

      if message.requested?(:names)
        dataset = dataset.where(name: message.names)
      end

      if message.requested?(:states)
        dataset = dataset.where(state: message.states)
      end

      if message.requested?(:guids)
        dataset = dataset.where(guid: message.guids)
      end

      if message.requested?(:app_guids)
        app_dataset ||= AppModel.select(:id)
        app_dataset = app_dataset.where(guid: message.app_guids)
      end

      if message.requested?(:space_guids)
        app_dataset ||= AppModel.select(:id)
        app_dataset = app_dataset.where(space_guid: message.space_guids)
      end

      if message.requested?(:organization_guids)
        org_dataset = Organization.select(:id).where(guid: message.organization_guids)
        space_dataset = Space.select(:guid).where(organization_id: org_dataset)
        app_dataset ||= AppModel.select(:id)
        app_dataset = app_dataset.where(space_guid: space_dataset)
      end

      dataset = dataset.where(app: app_dataset) if app_dataset

      SequelPaginator.new.get_page(dataset, pagination_options)
    end
  end
end
