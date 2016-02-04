module VCAP::CloudController
  class RouteMappingModel < Sequel::Model(:route_mappings)
    many_to_one :app, class: 'VCAP::CloudController::AppModel', table_name: :apps_v3, key: :app_v3_id
    many_to_one :route

    def validate
      validates_unique [:app_v3_id, :route_id]
    end
  end
end
