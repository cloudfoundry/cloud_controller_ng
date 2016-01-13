module VCAP::CloudController
  class RouteMapping < Sequel::Model
    many_to_one :app
    many_to_one :route

    export_attributes :app_port, :app_guid, :route_guid

    import_attributes :app_port, :app_guid, :route_guid

    def validate
      if self.app_port && !app.diego
        errors.add(:app_port, :diego_only)
      elsif app.diego && self.app_port && !app.ports.include?(self.app_port)
        errors.add(:app_port, :not_bound_to_app)
      end
      super
    end

    def before_save
      if !self.app_port && app.diego
        self.app_port = app.ports.first
      end
      app.add_route(route)
      super
    end

    def app_port
      if :app_port.nil?
        unless app.ports.blank?
          return app.ports[0]
        end
      end
      super
    end
  end
end
