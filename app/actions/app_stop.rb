module VCAP::CloudController
  class AppStop
    class InvalidApp < StandardError; end

    def initialize(user, user_email)
      @user = user
      @user_email = user_email
      @logger = Steno.logger('cc.action.app_stop')
    end

    def stop(app)
      app.db.transaction do
        app.update(desired_state: 'STOPPED')

        Repositories::Runtime::AppEventRepository.new.record_app_stop(
          app,
          @user.guid,
          @user_email
        )

        # this will force a query, may want to eager load processes in
        # AppFetcher
        app.processes.each do |process|
          process.update({
            state: 'STOPPED',
          })
        end
      end
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end
  end
end
