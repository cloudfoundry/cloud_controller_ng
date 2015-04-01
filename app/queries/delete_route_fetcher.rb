module VCAP::CloudController
  class DeleteRouteFetcher
    def fetch(app_guid, route_guid)
      app = dataset.where(:"#{AppModel.table_name}__guid" => app_guid).first
      return [nil, nil] if app.nil?
      route = app.routes_dataset.where(guid: route_guid).first
      [app, route]
    end

    private

    def dataset
      AppModel.dataset
    end
  end
end
