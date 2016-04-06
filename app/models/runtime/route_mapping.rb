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

    def self.user_visibility_filter(user)
      { app: App.user_visible(user) }
    end

    def validate
      validates_presence :app
      validates_presence :route

      if self.app_port && app && !app.diego
        errors.add(:app_port, :diego_only)
      elsif app && app.diego && self.app_port && app.ports.present? && !app.ports.include?(self.app_port)
        errors.add(:app_port, :not_bound_to_app)
      end

      if app && app.diego
        validates_unique [:app_id, :route_id, :app_port]
      else
        validates_unique [:app_id, :route_id]
      end

      super
    end

    def before_save
      if !self.user_provided_app_port && app.diego && app.user_provided_ports.present?
        self.app_port = app.user_provided_ports.first
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

    # user_provided_app_port method should be called to
    # get the value of app_port stored in the database
    alias_method :user_provided_app_port, :app_port
    def app_port
      saved_port = super

      return saved_port unless saved_port.blank?
      return app.ports.first if app && app.ports.present?
    end
  end
end
