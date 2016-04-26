module VCAP::CloudController
  class PackageListFetcher
    def fetch_all(message:)
      pagination_options = message.pagination_options
      dataset = PackageModel.dataset.eager(:docker_data)
      filter(pagination_options, message, dataset)
    end

    def fetch_for_spaces(message:, space_guids:)
      pagination_options = message.pagination_options
      dataset = PackageModel.select_all(:packages).join(:apps_v3, guid: :app_guid, space_guid: space_guids).eager(:docker_data)
      filter(pagination_options, message, dataset)
    end

    def fetch_for_app(message:)
      pagination_options = message.pagination_options
      app = AppModel.where(guid: message.app_guid).eager(:space, :organization).first
      return nil unless app

      dataset = app.packages_dataset.eager(:docker_data)
      [app, filter(pagination_options, message, dataset)]
    end

    private

    def filter(pagination_options, message, dataset)
      if message.requested? :states
        dataset = dataset.where(state: message.states)
      end

      if message.requested? :types
        dataset = dataset.where(type: message.types)
      end

      if message.requested? :app_guids
        dataset = dataset.where(app_guid: message.app_guids)
      end

      SequelPaginator.new.get_page(dataset, pagination_options)
    end
  end
end
