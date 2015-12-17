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
      package = PackageModel.find(guid: app.droplet.package_guid)

      app.db.transaction do
        app.lock!
        app.update(desired_state: 'STARTED')

        Repositories::Runtime::AppEventRepository.new.record_app_start(
          app,
          @user.guid,
          @user_email
        )
        app.processes.each do |process|
          process.update(update_hash(app, package))
        end
      end
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end

    private

    def update_hash(app, package)
      if package && package.docker_data
        docker_update_hash(app, package)
      else
        buildpack_update_hash(app, package)
      end
    end

    # FIXME: Sad. Order matters for this buildpack_update_hash, because setting
    # the package_hash on v2 App will reset the package_state to 'PENDING' to
    # mark for restaging, which is necessary for AppObserver behavior.

    def buildpack_update_hash(app, package)
      package_hash = package.nil? ? 'unknown' : package.package_hash

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

    def docker_update_hash(app, package)
      {
        state:                 'STARTED',
        diego:                 true,
        droplet_hash:          app.droplet.droplet_hash,
        docker_image:          package.docker_data.image,
        package_state:         'STAGED',
        package_pending_since: nil,
        environment_json:      app.environment_variables
      }
    end
  end
end
