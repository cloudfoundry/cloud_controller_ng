module VCAP::CloudController
  rest_controller :CrashEvent do
    serialization RestController::EntityOnlyObjectSerialization

    disable_default_routes
    path_base "apps"
    model_class_name :App

    permissions_required do
      read Permissions::CFAdmin
      read Permissions::OrgManager
      read Permissions::OrgUser
      read Permissions::SpaceManager
      read Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    def enumerate_by_app(id)
      app = find_id_and_validate_access(:read, id)

      ds = Models::CrashEvent.where(:app_id => app.id)
      ds = ds.where('timestamp <= ?', end_time) if end_time
      ds = ds.where("timestamp >= ?", start_time) if start_time

      RestController::Paginator.render_json(self.class, ds, self.class.path,
        @opts.merge(:serialization => serialization))
    end

    get "/v2/apps/:guid/crash_events", :enumerate_by_app

    private

    def start_time
      @start_time ||= parse_date_param("start_date")
    end

    def end_time
      @end_time ||= parse_date_param("end_date")
    end

    def parse_date_param(param)
      str = @params[param]
      Time.parse(str).localtime if str
    rescue
      raise Errors::CrashEventQueryInvalid
    end
  end
end
