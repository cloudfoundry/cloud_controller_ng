module VCAP::CloudController
  class OldRouteMapping < Sequel::Model(:apps_routes)
    many_to_one :app
    many_to_one :route

    export_attributes :app_id, :route_id

    import_attributes :app_id, :route_id
  end
end
