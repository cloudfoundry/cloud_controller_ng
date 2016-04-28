module VCAP::CloudController
  class PackageListFetcher
    def fetch_all(message:)
      app_dataset = AppModel.select(:id)
      filtered_paginator(message, app_dataset)
    end

    def fetch_for_spaces(message:, space_guids:)
      app_dataset = AppModel.select(:id).where(space_guid: space_guids)

      filtered_paginator(message, app_dataset)
    end

    def fetch_for_app(message:)
      app_dataset = AppModel.where(guid: message.app_guid).eager(:space, :organization)
      app = app_dataset.first
      return nil unless app

      [app, filtered_paginator(message, app_dataset)]
    end

    private

    def filtered_paginator(message, dataset)
      package_dataset = PackageModel.dataset.eager(:docker_data)
      filtered_dataset = filter_package_dataset(message, package_dataset).where(app: filter_app_dataset(message, dataset))
      SequelPaginator.new.get_page(filtered_dataset, message.pagination_options)
    end

    def filter_package_dataset(message, package_dataset)
      if message.requested? :states
        package_dataset = package_dataset.where(state: message.states)
      end

      if message.requested? :types
        package_dataset = package_dataset.where(type: message.types)
      end

      if message.requested? :guids
        package_dataset = package_dataset.where(:"#{PackageModel.table_name}__guid" => message.guids)
      end

      package_dataset
    end

    def filter_app_dataset(message, app_dataset)
      if message.requested? :app_guids
        app_dataset = app_dataset.where(app_guid: message.app_guids)
      end

      if message.requested? :space_guids
        app_dataset = app_dataset.where(space_guid: message.space_guids)
      end

      app_dataset
    end
  end
end
