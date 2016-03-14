module VCAP::CloudController
  class PackageListFetcher
    def fetch_all(pagination_options:)
      dataset = PackageModel.dataset.eager(:docker_data)
      paginate(dataset, pagination_options)
    end

    def fetch_for_spaces(pagination_options:, space_guids:)
      dataset = PackageModel.select_all(:packages).join(:apps_v3, guid: :app_guid, space_guid: space_guids).eager(:docker_data)
      paginate(dataset, pagination_options)
    end

    def fetch_for_app(app_guid:, pagination_options:)
      app = AppModel.where(guid: app_guid).eager(:space, :organization).all.first
      return nil unless app

      dataset = app.packages_dataset.eager(:docker_data)
      [app, paginate(dataset, pagination_options)]
    end

    private

    def paginate(dataset, pagination_options)
      SequelPaginator.new.get_page(dataset, pagination_options)
    end
  end
end
