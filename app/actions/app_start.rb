require 'actions/current_process_types'

module VCAP::CloudController
  class AppStart
    class InvalidApp < StandardError; end

    def initialize(user, user_email)
      @user = user
      @user_email = user_email
      @logger = Steno.logger('cc.action.app_start')
    end

    def start(app)
      app.db.transaction do
        app.lock!
        app.update(desired_state: 'STARTED')

        Repositories::AppEventRepository.new.record_app_start(
          app,
          @user.guid,
          @user_email
        )
        app.processes.each do |process|
          process.update(state: 'STARTED')
        end
      end
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end
  end
end
