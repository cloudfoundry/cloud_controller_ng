require 'cloud_controller/procfile'

module VCAP::CloudController
  class SetCurrentDroplet
    class InvalidApp < StandardError; end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
      @logger = Steno.logger('cc.action.procfile_parse')
    end

    def update_to(app, droplet)
      assign_droplet = { droplet_guid: droplet.guid }

      app.db.transaction do
        app.lock!

        app.update(assign_droplet)

        Repositories::AppEventRepository.new.record_app_map_droplet(
          app,
          app.space,
          @user_audit_info,
          assign_droplet
        )

        setup_processes(app)

        app.save
      end

      app
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end

    private

    def setup_processes(app)
      CurrentProcessTypes.new(@user_audit_info).process_current_droplet(app)
    end
  end
end
