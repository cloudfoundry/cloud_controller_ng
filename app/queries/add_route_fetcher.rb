module VCAP::CloudController
  class AddRouteFetcher
    def initialize(user)
      @user = user
    end

    def fetch(app_guid, route_guid)
      app = apps_dataset.where(:"#{AppModel.table_name}__guid" => app_guid).first
      return [nil, nil] if app.nil?
      route = routes_dataset(app.space_guid).where(:"#{Route.table_name}__guid" => route_guid).first
      [app, route]
    end

    private

    def apps_dataset
      ds = AppModel.dataset
      return ds if @user.admin?

      ds.select_all(AppModel.table_name).
        join(Space.table_name, guid: :space_guid).where(space_guid: @user.spaces_dataset.select(:guid)).
        join(Organization.table_name, id: :organization_id).where(status: 'active')
    end

    def routes_dataset(space_guid)
      ds = Route.dataset
      ds.select_all(Route.table_name).
        join(Space.table_name, id: :space_id).
        where(:"#{Space.table_name}__guid" => space_guid)
    end
  end
end
