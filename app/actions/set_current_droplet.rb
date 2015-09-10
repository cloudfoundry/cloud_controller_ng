require 'cloud_controller/procfile'

module VCAP::CloudController
  class SetCurrentDroplet
    class InvalidApp < StandardError; end

    def initialize(user, user_email)
      @user = user
      @user_email = user_email
      @logger = Steno.logger('cc.action.procfile_parse')
    end

    def update_to(app, droplet)
      app.db.transaction do
        app.lock!
        update_app(app, { droplet_guid: droplet.guid })
        procfile_parse.process_procfile(app)
        app.save
      end

      app
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end

    private

    def procfile_parse
      ProcfileParse.new(@user.guid, @user_email)
    end

    def update_app(app, fields)
      app.update(fields)
      Repositories::Runtime::AppEventRepository.new.record_app_set_current_droplet(
          app,
          app.space,
          @user.guid,
          @user_email,
          fields
      )
    end
  end
end
