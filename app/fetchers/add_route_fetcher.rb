module VCAP::CloudController
  class AddRouteFetcher
    class << self
      def fetch(app_guid:, process_type:, route_guid:)
        process, app, space, org = ProcessFetcher.
                                   fetch_for_app_by_type(app_guid: app_guid, process_type: process_type)
        return nil if app.nil?

        route = Route.where(guid: route_guid).first

        [app, route, process, space, org]
      end

      private

      def routes_dataset(space_guid)
        Route.dataset.select_all(Route.table_name).
          join(Space.table_name, id: :space_id).
          where("#{Space.table_name}__guid": space_guid)
      end
    end
  end
end
