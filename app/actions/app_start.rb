require 'actions/procfile_parse'

module VCAP::CloudController
  class AppStart
    class DropletNotFound < StandardError; end
    class InvalidApp < StandardError; end

    def initialize(user, user_email)
      @user = user
      @user_email = user_email
      @logger = Steno.logger('cc.action.app_start')
    end

    def start(app)
      raise DropletNotFound if !app.desired_droplet

      package = PackageModel.find(guid: app.desired_droplet.package_guid)
      package_hash = package.nil? ? 'unknown' : package.package_hash

      app.db.transaction do
        app.lock!
        app.update(desired_state: 'STARTED')

        Repositories::Runtime::AppEventRepository.new.record_app_start(
          app,
          @user.guid,
          @user_email
        )

        app.processes.each do |process|
          process.update({
            state: 'STARTED',
            package_hash: package_hash,
            package_state: 'STAGED',
            package_pending_since: nil,
            environment_json: app.environment_variables
          })
        end
      end
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end
  end
end
