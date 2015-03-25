module VCAP::CloudController
  class AppModelRoute < Sequel::Model(:apps_v3_routes)
    many_to_one :app, class: 'VCAP::CloudController::AppModel', table_name: :apps_v3, key: :app_v3_id
    many_to_one :route

    def validate
      validates_unique [:app_v3_id, :route_id]
    end
  end
end
