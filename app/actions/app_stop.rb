module VCAP::CloudController
  class AppStop
    class InvalidApp < StandardError; end

    def initialize(user, user_email)
      @user = user
      @user_email = user_email
    end

    def stop(app)
      app.db.transaction do
        app.lock!
        app.update(desired_state: 'STOPPED')

        Repositories::AppEventRepository.new.record_app_stop(
          app,
          @user.guid,
          @user_email
        )

        app.processes.each { |process| process.update(state: 'STOPPED') }
      end
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end
  end
end
