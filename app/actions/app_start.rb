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
          process.update(update_hash(app))
        end
      end
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end

    private

    def update_hash(app)
      if app.droplet.docker?
        docker_update_hash(app)
      else
        buildpack_update_hash(app)
      end
    end

    # Order matters for this buildpack_update_hash, because setting
    # the package_hash on v2 App will reset the package_state to 'PENDING' to
    # mark for restaging, which is necessary for AppObserver behavior.

    def buildpack_update_hash(app)
      package_hash = app.droplet.package.nil? ? 'unknown' : app.droplet.package.package_hash

      {
        state:                 'STARTED',
        diego:                 true,
        droplet_hash:          app.droplet.droplet_hash,
        package_hash:          package_hash,
        package_state:         'STAGED',
        package_pending_since: nil,
        environment_json:      app.environment_variables
      }
    end

    def docker_update_hash(app)
      {
        state:                 'STARTED',
        diego:                 true,
        droplet_hash:          app.droplet.droplet_hash,
        docker_image:          app.droplet.docker_receipt_image,
        package_state:         'STAGED',
        package_pending_since: nil,
        environment_json:      app.environment_variables
      }
    end
  end
end
