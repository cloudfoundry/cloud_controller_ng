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
      if self.saved_app_port.blank? && self.exists? && app.diego? && !app.docker_image.present?
        RouteMapping.dataset.where('app_port is null and id = ?', self.id).update(app_port: app.ports.first)
        reload
      end
      super
    end

    def self.user_visibility_filter(user)
      { app: App.user_visible(user) }
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
      if !self.saved_app_port && app.diego && !app.docker_image.present?
        self.app_port = app.ports.first
      end
      app.validate_route(route)
      super
    end

    def after_save
      app.handle_add_route(route)
      super
    end

    def after_destroy
      app.handle_remove_route(route)
      super
    end

    alias_method :saved_app_port, :app_port
    def app_port
      saved_port = super
      if !app.nil?
        saved_port = app.ports.first if saved_port.nil? && !app.ports.blank?
      end
      saved_port
    end
  end
end
