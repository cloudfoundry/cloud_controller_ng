module VCAP::CloudController
  class RouteMapping < Sequel::Model(:apps_routes)
    plugin :after_initialize

    many_to_one :app
    many_to_one :route

    export_attributes :app_port, :app_guid, :route_guid

    import_attributes :app_port, :app_guid, :route_guid

    def after_initialize
      if self.guid.blank? && self.exists?
        RouteMapping.dataset.where('guid is null and id = ?', self.id).update(guid: SecureRandom.uuid)
        reload
      end
      super
    end

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
      app.validate_route(route)
      super
    end

    def after_save
      app.handle_add_route(route)
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
