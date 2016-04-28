module VCAP::CloudController
  class ProcessListFetcher
    def fetch_all(message:)
      pagination_options = message.pagination_options
      dataset = ProcessModel.dataset
      dataset = filter(dataset, message)
      paginate(dataset, pagination_options)
    end

    def fetch_for_spaces(space_guids:, message:)
      pagination_options = message.pagination_options
      dataset = ProcessModel.select_all(:apps).join(:spaces, id: :space_id, guid: space_guids)
      dataset = filter(dataset, message)
      paginate(dataset, pagination_options)
    end

    def fetch_for_app(app_guid:, message:)
      pagination_options = message.pagination_options
      app = AppModel.where(guid: app_guid).eager(:space, :organization).all.first
      return nil unless app
      dataset = app.processes_dataset
      dataset = filter(dataset, message)
      [app, paginate(dataset, pagination_options)]
    end

    private

    def paginate(dataset, pagination_options)
      dataset = dataset.eager(:space)
      SequelPaginator.new.get_page(dataset, pagination_options)
    end

    def filter(dataset, message)
      dataset = dataset.where(type: message.types) if message.requested?(:types)
      dataset
    end
  end
end
