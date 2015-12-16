module VCAP::CloudController
  class RouteMapping < Sequel::Model
    many_to_one :app
    many_to_one :route

    export_attributes :app_port, :app_guid, :route_guid

    import_attributes :app_port, :app_guid, :route_guid

    def validate
      if self.app_port && !app.diego
        errors.add(:app_ports_for_diego_only, 'App ports are supported for Diego apps only.')
      end
      if !self.app_port && app.diego
        self.app_port = app.ports.first
      end
      app.add_route(route)
    end
  end
end
