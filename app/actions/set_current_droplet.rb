require 'cloud_controller/procfile'

module VCAP::CloudController
  class SetCurrentDroplet
    class InvalidApp < StandardError; end

    def initialize(user, user_email)
      @user       = user
      @user_email = user_email
      @logger     = Steno.logger('cc.action.procfile_parse')
    end

    def update_to(app, droplet)
      assign_droplet = { droplet_guid: droplet.guid }

      app.db.transaction do
        app.lock!

        app.update(assign_droplet)

        Repositories::AppEventRepository.new.record_app_map_droplet(
          app,
          app.space,
          @user.guid,
          @user_email,
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
      CurrentProcessTypes.new(@user.guid, @user_email).process_current_droplet(app)
    end
  end
end
