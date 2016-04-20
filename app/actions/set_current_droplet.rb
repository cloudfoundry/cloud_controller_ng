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
        current_process_types.process_current_droplet(app)
        app.save
      end

      app
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end

    private

    def current_process_types
      CurrentProcessTypes.new(@user.guid, @user_email)
    end

    def update_app(app, fields)
      app.update(fields)
      Repositories::AppEventRepository.new.record_app_map_droplet(
        app,
        app.space,
        @user.guid,
        @user_email,
        fields
      )
    end
  end
end
